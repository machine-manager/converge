alias Converge.{Unit, UnitError, UserUtil, GroupUtil, ThingPresent}
alias Gears.{FileUtil, IOUtil}

import Record, only: [defrecordp: 2, extract: 2]

# Functions shared by DirectoryPresent, FilePresent, SymlinkPresent, DirectoryEmpty
defmodule Converge.ThingPresent do
	@moduledoc false
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	def try_make_mutable(path) do
		System.cmd("chattr", ["-i", "--", path], stderr_to_stdout: true)
	end

	def make_mutable(path) do
		{"", 0} = try_make_mutable(path)
	end

	def make_immutable(path) do
		{"", 0} = System.cmd("chattr", ["+i", "--", path], stderr_to_stdout: true)
	end

	@doc """
	Remove an existing file or symlink or empty directory, even if it is immutable.
	"""
	def remove_existing(path) do
		# Ignore output and exit code, because 1) file may not exist 2) we may
		# be removing a symlink, which you can't chattr -i or +i
		try_make_mutable(path)
		case File.dir?(path) do
			true  -> File.rmdir!(path)
			false -> FileUtil.rm_f!(path)
		end
	end

	def meet_user_group_owner(u) do
		want_user    = if u.user  != nil, do: get_user_info(u.user)
		want_group   = if u.group != nil, do: get_group_info(u.group)
		chown_string = case {want_user, want_group} do
			{nil,  nil}   -> nil
			{user, nil}   -> "#{user.uid}"
			{nil,  group} -> ":#{group.gid}"
			{user, group} -> "#{user.uid}:#{group.gid}"
		end
		if chown_string do
			{_, 0} = System.cmd("chown", ["--no-dereference", chown_string, "--", u.path])
		end
	end

	def mode_without_type(mode) do
		use Bitwise

		mode &&& 0o7777
	end

	defp get_attrs(path) do
		{out, 0} = System.cmd("lsattr", ["-d", "--", path])
		lines = out
			|> String.replace_suffix("\n", "")
			|> String.split("\n")
		case lines do
			[line] -> line |> String.split(" ") |> hd
			_      -> raise(UnitError, "Expected 1 line from lsattr but got #{inspect lines}")
		end
	end

	def met_mutability?(u) do
		immutable?(u.path) == u.immutable
	end

	def immutable?(path) do
		attrs = get_attrs(path)
		attrs =~ "i"
	end

	def met_user_group_mode?(u) do
		want_user  = if u.user  != nil, do: get_user_info(u.user)
		want_group = if u.group != nil, do: get_group_info(u.group)
		case :file.read_link_info(u.path) do
			{:ok, file_info(mode: mode, uid: uid, gid: gid)} ->
				mode_without_type(mode) == u.mode           and
				(want_user  == nil or uid == want_user.uid) and
				(want_group == nil or gid == want_group.gid)
			_ -> false
		end
	end

	def get_user_info(user) do
		users     = UserUtil.get_users()
		user_info = users[user]
		if ! user_info do
			raise(UnitError, "User database is missing user #{inspect user}")
		end
		user_info
	end

	def get_group_info(group) do
		groups     = GroupUtil.get_groups()
		group_info = groups[group]
		if ! group_info do
			raise(UnitError, "Group database is missing group #{inspect group}")
		end
		group_info
	end

	def package_dependencies(_release), do: ["coreutils", "e2fsprogs"]
end


defmodule Converge.DirectoryPresent do
	@moduledoc """
	A directory exists at `path` with a specific `mode` and `immutable` flag,
	owned by `user` and `group`.  `user` or `group` (or both) may be `nil`, in
	which case the current user/group is used and the corresponding ownership
	check is skipped.
	"""
	@enforce_keys [:path, :mode]
	defstruct path: nil, mode: nil, immutable: false, user: nil, group: nil
end

defimpl Unit, for: Converge.DirectoryPresent do
	import Converge.ThingPresent

	def met?(u, _ctx) do
		File.dir?(u.path) and met_user_group_mode?(u) and met_mutability?(u)
	end

	def meet(u, _) do
		# We want the directory to be created with the right mode at creation time.
		# Use cmd("mkdir", ...) because File.mkdir* can't syscall mkdir with a mode.
		{out, status} = System.cmd(
			"mkdir", ["--mode=#{as_octal_string(u.mode)}", "--", u.path], stderr_to_stdout: true)
		case status do
			0 ->
				meet_user_group_owner(u)
				if u.immutable do
					make_immutable(u.path)
				end
			_ ->
				# mkdir may have failed because the directory already existed, but
				# we still need to fix the mode/user/group.
				case File.dir?(u.path) do
					true  ->
						# Must make mutable before we can chmod
						make_mutable(u.path)
						File.chmod!(u.path, u.mode)
						meet_user_group_owner(u)
						if u.immutable do
							make_immutable(u.path)
						end
					false ->
						raise(UnitError, "mkdir failed to create a directory: #{out}")
				end
		end
	end

	defp as_octal_string(num) do
		inspect(num, base: :octal) |> String.split("o") |> List.last
	end

	def package_dependencies(_, release), do: ThingPresent.package_dependencies(release)
end

defimpl Inspect, for: Converge.DirectoryPresent do
	import Inspect.Algebra

	def inspect(u, opts) do
		concat([
			color("%Converge.DirectoryPresent{", :map, opts),
			color("path: ",      :atom, opts),
			to_doc(u.path,              opts),
			color(", ",          :map,  opts),
			color("mode: ",      :atom, opts),
			to_doc(u.mode, %Inspect.Opts{opts | base: :octal}),
			color(", ",          :map,  opts),
			color("immutable: ", :atom, opts),
			to_doc(u.immutable,         opts),
			color(", ",          :map,  opts),
			color("user: ",      :atom, opts),
			to_doc(u.user,              opts),
			color(", ",          :map,  opts),
			color("group: ",     :atom, opts),
			to_doc(u.group,             opts),
			color("}",           :map,  opts)
		])
	end
end


defmodule Converge.FilePresent do
	@moduledoc """
	A file exists at `path` with content `content`, a specific `mode`,
	`immutable` flag, owned by `user` and `group`.  `user` or `group` (or both)
	may be `nil`, in which case the current user/group is used and the
	corresponding ownership check is skipped.
	"""
	@enforce_keys [:path, :content, :mode]
	defstruct path: nil, content: nil, mode: nil, immutable: false, user: nil, group: nil
end

defimpl Unit, for: Converge.FilePresent do
	import Converge.ThingPresent

	def met?(u, _ctx) do
		met_user_group_mode?(u) and met_mutability?(u) and met_contents?(u)
	end

	def meet(u, _) do
		# It's safer to unlink the file first, because it may be a shell script, and
		# shells handle modified scripts very poorly.  If unlinked first, the shell
		# will continue running the old (unlinked) script instead of crashing.
		#
		# Removing the file first also avoids the problem of very briefly granting
		# access to a new user/group that should not be able to see the old file contents.
		remove_existing(u.path)

		f = File.open!(u.path, [:write])
		try do
			# After opening, chmod before writing possibly-secret content
			File.chmod!(u.path, u.mode)
			meet_user_group_owner(u)
			IOUtil.binwrite!(f, u.content)
			if u.immutable do
				make_immutable(u.path)
			end
		after
			File.close(f)
		end
	end

	# TODO: guard against giant files in binread
	defp met_contents?(u) do
		case File.open(u.path, [:read]) do
			{:error, _} -> false
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing    -> u.content == existing
			end
		end
	end

	def package_dependencies(_, release), do: ThingPresent.package_dependencies(release)
end

defimpl Inspect, for: Converge.FilePresent do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		len = byte_size(u.content)
		concat([
			color("%Converge.FilePresent{", :map, opts),
			color("path: ",      :atom, opts),
			to_doc(u.path,              opts),
			color(", ",          :map,  opts),
			color("content: ",   :atom, opts),
			counted_noun(len, "byte", "bytes"),
			color(", ",          :map,  opts),
			color("mode: ",      :atom, opts),
			to_doc(u.mode, %Inspect.Opts{opts | base: :octal}),
			color(", ",          :map,  opts),
			color("immutable: ", :atom, opts),
			to_doc(u.immutable,         opts),
			color(", ",          :map,  opts),
			color("user: ",      :atom, opts),
			to_doc(u.user,              opts),
			color(", ",          :map,  opts),
			color("group: ",     :atom, opts),
			to_doc(u.group,             opts),
			color("}",           :map,  opts),
		])
	end
end


defmodule Converge.SymlinkPresent do
	@moduledoc """
	A symlink exists at `path` pointing to `target`.  The symlink is owned
	by `user` and `group`.  `user` or `group` (or both) may be `nil`, in which
	case the current user/group is used and the corresponding ownership check is
	skipped.
	"""
	@enforce_keys [:path, :target]
	defstruct path: nil, target: nil, user: nil, group: nil
end

defimpl Unit, for: Converge.SymlinkPresent do
	import Converge.ThingPresent
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	def met?(u, _ctx) do
		met_symlink_to_target?(u) and met_user_group?(u)
	end

	def meet(u, _) do
		remove_existing(u.path)
		case File.ln_s(u.target, u.path) do
			:ok ->
				meet_user_group_owner(u)
			{:error, reason} ->
				raise(UnitError, "failed to create symlink: #{inspect u.path}; reason: #{reason}")
		end
	end

	def met_symlink_to_target?(u) do
		# read_link_all gives us a list except in cases where the filename
		# can only be represented as a binary.  If we get a list, convert
		# it to a binary (Elixir string).
		case :file.read_link_all(u.path) do
			{:ok, target_l} -> IO.chardata_to_string(target_l) == u.target
			_               -> false
		end
	end

	def met_user_group?(u) do
		want_user  = if u.user  != nil, do: get_user_info(u.user)
		want_group = if u.group != nil, do: get_group_info(u.group)
		case :file.read_link_info(u.path) do
			{:ok, file_info(type: :symlink, uid: uid, gid: gid)} ->
				(want_user  == nil or uid == want_user.uid) and
				(want_group == nil or gid == want_group.gid)
			_ -> false
		end
	end

	def package_dependencies(_, release), do: ThingPresent.package_dependencies(release)
end


defmodule Converge.FileMissing do
	@moduledoc """
	A file at `path` does not exist.  Converging may remove a file or empty
	directory.  If pointing to a symlink, will remove the symlink, not the
	target.
	"""
	@enforce_keys [:path]
	defstruct path: nil
end

defimpl Unit, for: Converge.FileMissing do
	import Converge.ThingPresent

	def met?(u, _ctx) do
		not FileUtil.exists?(u.path)
	end

	def meet(u, _) do
		remove_existing(u.path)
	end

	def package_dependencies(_, release), do: ThingPresent.package_dependencies(release)
end


defmodule Converge.DirectoryEmpty do
	@moduledoc """
	Directory at `path` is empty.  Directory must already exist.

	Converging will remove files and empty directories in `path`, but not
	recursively.
	"""
	@enforce_keys [:path]
	defstruct path: nil
end

defimpl Unit, for: Converge.DirectoryEmpty do
	import Converge.ThingPresent

	def met?(u, _ctx) do
		case File.ls(u.path) do
			{:ok, children} -> children == []
			{:error, _}     -> false
		end
	end

	def meet(u, _) do
		children = File.ls!(u.path)
		case children do
			[]   -> nil
			some ->
				was_immutable = immutable?(u.path)
				if was_immutable do
					try_make_mutable(u.path)
				end
				for child <- some do
					child_path = Path.join(u.path, child)
					remove_existing(child_path)
				end
				# Restore original mutability state
				if was_immutable do
					make_immutable(u.path)
				end
		end
	end

	def package_dependencies(_, release), do: ThingPresent.package_dependencies(release)
end
