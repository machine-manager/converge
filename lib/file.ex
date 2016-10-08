alias Converge.{Unit, UnitError, UserUtil, GroupUtil}
alias Gears.{FileUtil, IOUtil}

use Bitwise

import Record, only: [defrecordp: 2, extract: 2]

defmodule Converge.ThingPresent do
	@moduledoc """
	Functions shared by `DirectoryPresent` and `FilePresent`.
	"""
	defmacro __using__(_) do
		quote do
			defp get_user_info(user) do
				users     = UserUtil.get_users()
				user_info = users[user]
				if ! user_info do
					raise UnitError, message: "OS lacks user #{inspect user}"
				end
				user_info
			end

			defp get_group_info(group) do
				groups     = GroupUtil.get_groups()
				group_info = groups[group]
				if ! group_info do
					raise UnitError, message: "OS lacks group #{inspect group}"
				end
				group_info
			end
		end
	end
end

defmodule Converge.DirectoryPresent do
	@enforce_keys [:path, :mode]
	defstruct path: nil, mode: nil, user: "root", group: "root"
end

defimpl Unit, for: Converge.DirectoryPresent do
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")
	use Converge.ThingPresent

	defp mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp met_mode?(p) do
		case :file.read_file_info(p.path) do
			{:ok, file_info(mode: mode)} ->
				mode_without_type(mode) == p.mode
			_ -> false
		end
	end

	def met?(p) do
		File.dir?(p.path) and met_mode?(p)
	end

	defp as_octal_string(num) do
		inspect(num, base: :octal) |> String.split("o") |> List.last
	end

	def meet(p) do
		# We want the directory to be created with the right mode at creation time.
		# Use cmd("mkdir", ...) because File.mkdir* can't syscall mkdir with a mode.
		{out, status} = System.cmd("mkdir", ["--mode=#{as_octal_string(p.mode)}", "--", p.path], stderr_to_stdout: true)
		case status do
			0 -> nil
			_ ->
				# mkdir may have failed because the directory already existed, but
				# we still need to fix the mode.
				case File.dir?(p.path) do
					true  -> File.chmod!(p.path, p.mode)
					false -> raise UnitError, message: "mkdir failed to create a directory: #{out}"
				end
		end
	end
end


defmodule Converge.FilePresent do
	@enforce_keys [:path, :content, :mode]
	defstruct path: nil, content: nil, mode: nil, user: "root", group: "root"
end

defimpl Unit, for: Converge.FilePresent do
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")
	use Converge.ThingPresent

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

	defp mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp met_mode_user_group?(p) do
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

	def met?(p) do
		met_mode_user_group?(p) and met_contents?(p)
	end

	def meet(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)

		# It's safer to unlink the file first, because it may be a shell script, and
		# shells handle modified scripts very poorly.  If unlinked first, the shell
		# will continue running the old (unlinked) script instead of crashing.
		FileUtil.rm_f!(p.path)

		# After opening, must chmod before writing possibly-secret content
		f = File.open!(p.path, [:write])
		# TODO: combine these into one :file.set_file_info
		File.chmod!(p.path, p.mode)
		File.chown!(p.path, want_user.uid)
		File.chgrp!(p.path, want_group.gid)

		try do
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
