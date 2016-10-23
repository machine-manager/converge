alias Converge.Unit

defmodule Converge.UserUtil do
	def get_users() do
		shadow = File.read!("/etc/shadow")
			|> String.trim_trailing("\n")
			|> String.split("\n")
			|> Enum.map(&shadow_line_to_tuple/1)
			|> Enum.into(%{})

		File.read!("/etc/passwd")
			|> String.trim_trailing("\n")
			|> String.split("\n")
			|> Enum.map(&passwd_line_to_tuple/1)
			|> Enum.map(fn {name, details} -> {name, Map.merge(details, shadow[name])} end)
			|> Enum.into(%{})
	end

	defp shadow_line_to_tuple(line) do
		[name, crypted_password, _] = String.split(line, ":", parts: 3)
		locked = crypted_password |> String.starts_with?("!")
		{name, %{crypted_password: crypted_password, locked: locked}}
	end

	defp passwd_line_to_tuple(line) do
		[name, "x", uid_s, gid_s, comment, home, shell] = String.split(line, ":")
		{uid, ""} = Integer.parse(uid_s)
		{gid, ""} = Integer.parse(gid_s)
		{name, %{uid: uid, gid: gid, comment: comment, home: home, shell: shell}}
	end
end

defmodule Converge.GroupUtil do
	defp group_line_to_tuple(line) do
		[name, "x", gid_s, members_s] = String.split(line, ":")
		{gid, ""} = Integer.parse(gid_s)
		members = case members_s do
			"" -> []
			s  -> s |> String.split(",")
		end
		{name, %{gid: gid, members: members}}
	end

	def get_groups() do
		File.read!("/etc/group")
			|> String.trim_trailing("\n")
			|> String.split("\n")
			|> Enum.map(&group_line_to_tuple/1)
			|> Enum.into(%{})
	end
end

defmodule Converge.UserPresent do
	@moduledoc """
	A user exists and and has a certain uid, gid, comment, home, and shell.

	`uid`, `gid`, `comment`, and `locked` are optional, and if not specified,
	will be automatically assigned for new users, or left unchanged for existing
	users.

	New users will be a non-system user with a home directory, created as needed.
	"""
	@enforce_keys [:name, :home, :shell]
	defstruct name: nil, uid: nil, gid: nil, comment: nil, home: nil, shell: nil, locked: nil
end

defimpl Unit, for: Converge.UserPresent do
	import Gears.LangUtil, only: [oper_if: 3]
	import ExUnit.Assertions, only: [assert: 2]
	alias Converge.UserUtil

	@docp """
	Take a map and return a new map without any k/v pairs that have a nil value
	"""
	defp without_nil_values(m) do
		m
			|> Enum.filter(fn {k, v} -> v != nil end)
			|> Enum.into(%{})
	end

	def met?(u) do
		user = UserUtil.get_users()[u.name]
		case user do
			nil -> false
			_   ->
				wanted = u
					|> Map.take([:uid, :gid, :comment, :home, :shell, :locked])
					|> without_nil_values
				current = user |> Map.take(Map.keys(wanted))
				current == wanted
		end
	end

	defp meet_modify(u) do
		# Note: we refuse to change uid or gid, because it's dangerous
		# and possibly a configuration mistake.
		args = {[], &Kernel.++/2}
			|> oper_if(u.locked  == true,  ["--lock"])
			|> oper_if(u.locked  == false, ["--unlock"])
			|> oper_if(u.comment != nil,   ["--comment", u.comment])
			|> oper_if(true,               ["--shell", u.shell])
			|> oper_if(true,               ["--home", u.home])
			|> elem(0)
		{"", 0} = System.cmd("usermod", args ++ ["--", u.name])
	end

	defp meet_add(u) do
		args = {[], &Kernel.++/2}
			|> oper_if(u.uid,     ["--uid",      "#{u.uid}"])
			|> oper_if(u.uid,     ["--gid",      "#{u.gid}"])
			|> oper_if(u.comment, ["--comment",  u.comment])
			|> oper_if(true,      ["--shell",    u.shell])
			|> oper_if(true,      ["--home-dir", u.home])
			|> oper_if(true,      ["--create-home"])
			|> elem(0)
		{out, 0} = System.cmd("useradd", args ++ ["--", u.name], stderr_to_stdout: true)
		assert \
			out == "" or
			out == \
				"""
				useradd: warning: the home directory already exists.
				Not copying any file from skel directory into it.
				""", "Unexpected output from useradd: #{inspect out}"
	end

	def meet(u, rep) do
		exists = UserUtil.get_users() |> Map.has_key?(u.name)
		case exists do
			true   -> meet_modify(u)
			false  -> meet_add(u)
		end
	end
end


defmodule Converge.UserDisabled do
	@moduledoc """
	A user is disabled.

	We disable, instead of delete, users that are no longer needed, because
	adduser and useradd recycle UIDs, and with this recycling, new users gain
	access to files left behind by deleted users.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.UserDisabled do
	alias Converge.UserUtil

	def met?(u) do
		%{shell: shell, locked: locked} = UserUtil.get_users()[u.name]
		locked and shell == "/bin/false"
	end

	def meet(u, rep) do
		{"", 0} = System.cmd("usermod", [
			"--lock",
			"--shell",   "/bin/false",
			"--comment", "Disabled but kept to prevent UID recycling",
			u.name
		])
	end
end


defmodule Converge.UserDeleted do
	@moduledoc """
	A user is deleted.

	Because adduser and useradd recycle UIDs, you should almost never use this,
	except for testing, or for deleting users that have no files remaining on
	the the filesystem.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.UserDeleted do
	alias Converge.UserUtil

	def met?(u) do
		UserUtil.get_users()
			|> Map.has_key?(u.name)
			|> Kernel.not
	end

	def meet(u, rep) do
		{"", 0} = System.cmd("userdel", ["--", u.name])
	end
end
