alias Converge.{Unit, UnitError, UserUtil, GroupUtil}
alias Gears.{FileUtil, IOUtil}

use Bitwise

import Record, only: [defrecordp: 2, extract: 2]

# Functions shared by DirectoryPresent, FilePresent, SymlinkPresent
defmodule Converge.ThingPresent do
	@moduledoc false
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	def make_mutable(p) do
		{_, 0} = System.cmd("chattr", ["-i", "--", p.path])
	end

	def meet_mutability(p) do
		if p.immutable do
			{_, 0} = System.cmd("chattr", ["+i", "--", p.path])
		end
	end

	def meet_user_group_owner(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)

		{_, 0} = System.cmd("chown",
			["--no-dereference", "#{want_user.uid}:#{want_group.gid}", "--", p.path])
	end

	def mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp get_attrs(path) do
		{out, 0} = System.cmd("lsattr", ["-d", "--", path])
		lines = out |> String.trim_trailing("\n") |> String.split("\n")
		case lines do
			[line | _] -> line |> String.split(" ") |> hd
			_          -> raise UnitError, message: "Expected 1 line from lsattr but got #{inspect lines}"
		end
	end

	def met_mutability?(p) do
		attrs = get_attrs(p.path)
		has_i = String.match?(attrs, ~r"i")
		has_i == p.immutable
	end

	def met_user_group_mode?(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)
		case :file.read_link_info(p.path) do
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
			raise UnitError, message: "User database is missing user #{inspect user}"
		end
		user_info
	end

	def get_group_info(group) do
		groups     = GroupUtil.get_groups()
		group_info = groups[group]
		if ! group_info do
			raise UnitError, message: "Group database is missing group #{inspect group}"
		end
		group_info
	end
end


defmodule Converge.DirectoryPresent do
	@moduledoc """
	A directory exists at `path` with a specific `mode` and `immutable` flag,
	owned by `user` and `group`.
	"""
	@enforce_keys [:path, :mode]
	defstruct path: nil, mode: nil, immutable: false, user: "root", group: "root"
end

defimpl Unit, for: Converge.DirectoryPresent do
	import Converge.ThingPresent

	def met?(p) do
		File.dir?(p.path) and met_user_group_mode?(p) and met_mutability?(p)
	end

	def meet(p, _) do
		# We want the directory to be created with the right mode at creation time.
		# Use cmd("mkdir", ...) because File.mkdir* can't syscall mkdir with a mode.
		{out, status} = System.cmd(
			"mkdir", ["--mode=#{as_octal_string(p.mode)}", "--", p.path], stderr_to_stdout: true)
		case status do
			0 ->
				meet_user_group_owner(p)
				meet_mutability(p)
			_ ->
				# mkdir may have failed because the directory already existed, but
				# we still need to fix the mode/user/group.
				case File.dir?(p.path) do
					true  ->
						make_mutable(p)
						File.chmod!(p.path, p.mode)
						meet_user_group_owner(p)
						meet_mutability(p)
					false ->
						raise UnitError, message: "mkdir failed to create a directory: #{out}"
				end
		end
	end

	defp as_octal_string(num) do
		inspect(num, base: :octal) |> String.split("o") |> List.last
	end
end


defmodule Converge.FilePresent do
	@moduledoc """
	A file exists at `path` with content `content`, a specific `mode` `immutable` flag,
	owned by `user` and `group`.
	"""
	@enforce_keys [:path, :content, :mode]
	defstruct path: nil, content: nil, mode: nil, immutable: false, user: "root", group: "root"
end

defimpl Unit, for: Converge.FilePresent do
	import Converge.ThingPresent

	def met?(p) do
		met_user_group_mode?(p) and met_mutability?(p) and met_contents?(p)
	end

	def meet(p, _) do
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
			File.chmod!(p.path, p.mode)
			meet_user_group_owner(p)
			IOUtil.binwrite!(f, p.content)
			meet_mutability(p)
		after
			File.close(f)
		end
	end

	# TODO: guard against giant files in binread
	defp met_contents?(p) do
		case File.open(p.path, [:read]) do
			{:error, _} -> false
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing    -> p.content == existing
			end
		end
	end
end


defmodule Converge.SymlinkPresent do
	@moduledoc """
	A symlink exists at `path` pointing to `dest`, owned by `user` and `group`.
	"""
	@enforce_keys [:path, :dest]
	defstruct path: nil, dest: nil, user: "root", group: "root"
end

defimpl Unit, for: Converge.SymlinkPresent do
	import Converge.ThingPresent
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	def met?(p) do
		met_symlink_to_dest?(p) and met_user_group?(p)
	end

	def meet(p, _) do
		FileUtil.rm_f!(p.path)
		case File.ln_s(p.dest, p.path) do
			:ok ->
				meet_user_group_owner(p)
			{:error, reason} ->
				raise UnitError, message:
					"failed to create symlink: #{inspect p.path}; reason: #{reason}"
		end
	end

	def met_symlink_to_dest?(p) do
		# read_link_all gives us a list except in cases where the filename
		# can only be represented as a binary.  If we get a list, convert
		# it to a binary (Elixir string).
		case :file.read_link_all(p.path) do
			{:ok, dest_l} -> IO.chardata_to_string(dest_l) == p.dest
			_             -> false
		end
	end

	def met_user_group?(p) do
		want_user  = get_user_info(p.user)
		want_group = get_group_info(p.group)
		case :file.read_link_info(p.path) do
			{:ok, file_info(type: :symlink, uid: uid, gid: gid)} ->
				uid == want_user.uid and
				gid == want_group.gid
			_ -> false
		end
	end
end


defmodule Converge.FileMissing do
	@moduledoc """
	A file at `path` does not exist.  Fails to converge if `path` points to
	a directory.
	"""
	@enforce_keys [:path]
	defstruct path: nil
end

defimpl Unit, for: Converge.FileMissing do
	def met?(p) do
		not File.exists?(p.path)
	end

	def meet(p, _) do
		# Ignore output and exit code, because we may be removing a symlink
		# on which you can't chattr -i or +i
		System.cmd("chattr", ["-i", "--", p.path], stderr_to_stdout: true)
		FileUtil.rm_f!(p.path)
	end
end
