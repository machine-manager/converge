alias Converge.{Unit, UnitError, UserUtil, GroupUtil}
alias Gears.{FileUtil, IOUtil}

use Bitwise

import Record, only: [defrecordp: 2, extract: 2]

# Functions shared by DirectoryPresent, FilePresent
defmodule Converge.ThingPresent do
	@moduledoc false

	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	def mode_without_type(mode) do
		mode &&& 0o7777
	end

	def met_user_group_mode?(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)
		case :file.read_file_info(p.path) do
			{:ok, file_info(mode: mode, uid: uid, gid: gid)} ->
				mode_without_type(mode) == p.mode and
				uid == want_user.uid and
				gid == want_group.gid
			_ -> false
		end
	end

	def get_user_info(user) do
		users     = UserUtil.get_users()
		user_info = users[user]
		if ! user_info do
			raise UnitError, message: "OS lacks user #{inspect user}"
		end
		user_info
	end

	def get_group_info(group) do
		groups     = GroupUtil.get_groups()
		group_info = groups[group]
		if ! group_info do
			raise UnitError, message: "OS lacks group #{inspect group}"
		end
		group_info
	end
end


defmodule Converge.DirectoryPresent do
	@enforce_keys [:path, :mode]
	defstruct path: nil, mode: nil, user: "root", group: "root"
end

defimpl Unit, for: Converge.DirectoryPresent do
	import Converge.ThingPresent

	def met?(p) do
		File.dir?(p.path) and met_user_group_mode?(p)
	end

	defp as_octal_string(num) do
		inspect(num, base: :octal) |> String.split("o") |> List.last
	end

	def meet_user_group_owner(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)

		File.chown!(p.path, want_user.uid)
		File.chgrp!(p.path, want_group.gid)
	end

	def meet(p) do
		# We want the directory to be created with the right mode at creation time.
		# Use cmd("mkdir", ...) because File.mkdir* can't syscall mkdir with a mode.
		{out, status} = System.cmd("mkdir", ["--mode=#{as_octal_string(p.mode)}", "--", p.path], stderr_to_stdout: true)
		case status do
			0 ->
				meet_user_group_owner(p)
			_ ->
				# mkdir may have failed because the directory already existed, but
				# we still need to fix the mode/user/group.
				case File.dir?(p.path) do
					true  ->
						File.chmod!(p.path, p.mode)
						meet_user_group_owner(p)
					false ->
						raise UnitError, message: "mkdir failed to create a directory: #{out}"
				end
		end
	end
end


defmodule Converge.FilePresent do
	@enforce_keys [:path, :content, :mode]
	defstruct path: nil, content: nil, mode: nil, user: "root", group: "root"
end

defimpl Unit, for: Converge.FilePresent do
	import Converge.ThingPresent

	defp met_contents?(p) do
		case File.open(p.path, [:read]) do
			# TODO: guard against giant files
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing -> p.content == existing
			end
			{:error, _} -> false
		end
	end

	def met?(p) do
		met_user_group_mode?(p) and met_contents?(p)
	end

	def meet(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)

		# It's safer to unlink the file first, because it may be a shell script, and
		# shells handle modified scripts very poorly.  If unlinked first, the shell
		# will continue running the old (unlinked) script instead of crashing.
		#
		# Removing the file first also avoids the problem of very briefly granting
		# access to a new user/group that should not be able to see the old file contents.
		FileUtil.rm_f!(p.path)

		f = File.open!(p.path, [:write])
		try do
			# After opening, chmod before writing possibly-secret content
			# TODO: combine chmod/chown/chgrp into one :file.set_file_info
			File.chmod!(p.path, p.mode)
			File.chown!(p.path, want_user.uid)
			File.chgrp!(p.path, want_group.gid)
			IOUtil.binwrite!(f, p.content)
		after
			File.close(f)
		end
	end
end


defmodule Converge.FileMissing do
	@enforce_keys [:path]
	defstruct path: nil
end

defimpl Unit, for: Converge.FileMissing do
	def met?(p) do
		not File.exists?(p.path)
	end

	def meet(p) do
		FileUtil.rm_f!(p.path)
	end
end
