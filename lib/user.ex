alias Converge.{
	Unit, UnitError, Runner, All, DirectoryPresent, FilePresent,
	UserAuthorizedKeys, UserUtil, UserPresent, UserDisabled}

defmodule Converge.UserUtil do
	def get_users() do
		shadow = case File.read("/etc/shadow") do
			{:error, _}    -> %{}
			{:ok, content} ->
				content
				|> String.trim_trailing("\n")
				|> String.split("\n")
				|> Enum.map(&shadow_line_to_tuple/1)
				|> Enum.into(%{})
		end

		File.read!("/etc/passwd")
		|> String.trim_trailing("\n")
		|> String.split("\n")
		|> Enum.map(&passwd_line_to_tuple/1)
		|> Enum.map(fn {name, details} -> {name, Map.merge(details, shadow[name] || %{})} end)
		|> Enum.into(%{})
	end

	defp shadow_line_to_tuple(line) do
		[name, crypted_password, _] = String.split(line, ":", parts: 3)
		{name,
			%{
				crypted_password: crypted_password,
				locked:           crypted_password_is_locked(crypted_password)
			}
		}
	end

	def crypted_password_is_locked(crypted_password) do
		String.starts_with?(crypted_password, "!")
	end

	defp passwd_line_to_tuple(line) do
		[name, "x", uid_s, gid_s, comment, home, shell] = String.split(line, ":")
		{uid, ""} = Integer.parse(uid_s)
		{gid, ""} = Integer.parse(gid_s)
		{name, %{uid: uid, gid: gid, comment: comment, home: home, shell: shell}}
	end

	@doc """
	Get the minimum UID for regular users created by useradd.
	"""
	def get_uid_min() do
		get_login_defs_integer(~r/^UID_MIN\s/)
	end

	@doc """
	Get the maximum UID for regular users created by useradd.
	"""
	def get_uid_max() do
		get_login_defs_integer(~r/^UID_MAX\s/)
	end

	defp get_login_defs_integer(regexp) do
		File.read!("/etc/login.defs")
		|> String.split("\n")
		|> Enum.filter(&Regex.match?(regexp, &1))
		|> List.first
		|> String.split(~r"\s")
		|> List.last
		|> String.to_integer
	end
end


defmodule Converge.GroupUtil do
	def get_groups() do
		File.read!("/etc/group")
		|> String.trim_trailing("\n")
		|> String.split("\n")
		|> Enum.map(&group_line_to_tuple/1)
		|> Enum.into(%{})
	end

	defp group_line_to_tuple(line) do
		[name, "x", gid_s, members_s] = String.split(line, ":")
		{gid, ""} = Integer.parse(gid_s)
		members = case members_s do
			"" -> []
			s  -> String.split(s, ",")
		end
		{name, %{gid: gid, members: members}}
	end
end


defmodule Converge.UserAuthorizedKeys do
	@enforce_keys [:name, :authorized_keys]
	defstruct name: nil, authorized_keys: nil
end

defimpl Unit, for: Converge.UserAuthorizedKeys do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	def make_unit(u) do
		home = UserUtil.get_users()[u.name].home
		%All{units: [
			# home directory might not exist if it was changed
			%DirectoryPresent{path: home,                      mode: 0o750, user: u.name, group: u.name},
			%DirectoryPresent{path: "#{home}/.ssh",            mode: 0o700, user: u.name, group: u.name},
			%FilePresent{path: "#{home}/.ssh/authorized_keys", mode: 0o600, user: u.name, group: u.name, content: authorized_keys_file(u)},
		]}
	end

	defp authorized_keys_file(u) do
		u.authorized_keys
		|> Enum.map(fn key -> "#{key}\n" end)
		|> Enum.join
	end

	def package_dependencies(_, _release), do: []
end


defmodule Converge.User do
	@moduledoc """
	See the documentation for `Converge.UserPresent`.

	`User` is used only by `RegularUsersPresent`, so it does not implement `Unit`.
	"""
	@enforce_keys [:name, :home, :shell]
	defstruct \
		name: nil, uid: nil, gid: nil, comment: nil, home: nil, shell: nil,
		locked: nil, crypted_password: nil, authorized_keys: []
end


defmodule Converge.UserPresent do
	@moduledoc """
	A user exists and and has a certain uid, gid, comment, home, and shell,
	and authorized_keys.

	`uid`, `gid`, `comment`, and `locked` are optional, and if not specified,
	will be automatically assigned for new users, or left unchanged for existing
	users.  New users will be locked by default (`crypted_password == "!"`).

	New users will be a regular (i.e. non-system) user with a home directory,
	created as needed.

	Use `RegularUsers` instead of `UserPresent` directly, to avoid leaving
	behind unwanted users after removing a `UserPresent` unit in a configuration.
	"""
	@enforce_keys [:name, :home, :shell]
	defstruct \
		name: nil, uid: nil, gid: nil, comment: nil, home: nil, shell: nil,
		locked: nil, crypted_password: nil, authorized_keys: []
end

defimpl Unit, for: Converge.UserPresent do
	import Gears.LangUtil, only: [oper_if: 3]

	def met?(u, ctx) do
		ensure_password_and_locked_consistency(u)
		user = UserUtil.get_users()[u.name]
		case user do
			nil -> false
			_   ->
				wanted = u
					|> Map.take([:uid, :gid, :comment, :home, :shell, :locked])
					|> without_nil_values
				current = Map.take(user, Map.keys(wanted))
				current == wanted
		end and Runner.met?(authorized_keys_unit(u), ctx)
	end

	def meet(u, ctx) do
		ensure_password_and_locked_consistency(u)
		exists = Map.has_key?(UserUtil.get_users(), u.name)
		if exists do
			meet_modify(u)
		else
			meet_add(u)
		end
		Runner.converge(authorized_keys_unit(u), ctx)
	end

	# Take a map and return a new map without any k/v pairs that have a nil value
	defp without_nil_values(m) do
		m
		|> Enum.filter(fn {_, v} -> v != nil end)
		|> Enum.into(%{})
	end

	# Ensure consistency in `crypted_password` and `locked` early, before the
	# unit fails to converge for a reason that is hard to decipher.
	defp ensure_password_and_locked_consistency(u) do
		if u.locked != nil and u.crypted_password != nil do
			if not UserUtil.crypted_password_is_locked(u.crypted_password) == u.locked do
				case u.locked do
					true  -> raise(UnitError, ~s(Expected crypted_password to be locked, but it lacked a leading "!"))
					false -> raise(UnitError, ~s(Expected crypted_password to be unlocked, but it had a leading "!"))
				end
			end
		end
	end

	defp meet_modify(u) do
		have_password = u.crypted_password != nil
		args = {[], &Kernel.++/2}
			|> oper_if(u.locked  == true,  ["--lock"])
			|> oper_if(u.locked  == false, ["--unlock"])
			|> oper_if(u.comment != nil,   ["--comment",  u.comment])
			|> oper_if(have_password,      ["--password", u.crypted_password])
			|> oper_if(true,               ["--shell",    u.shell])
			|> oper_if(true,               ["--home",     u.home])
			|> elem(0)
		# Note: we refuse to change uid or gid, because it's dangerous
		# and possibly a configuration mistake.
		{out, 0} = System.cmd("usermod", args ++ ["--", u.name], stderr_to_stdout: true)
		if not (out == "" or out == "usermod: no changes\n") do
			raise(UnitError, "Unexpected output from usermod: #{inspect out}")
		end
	end

	defp meet_add(u) do
		have_password = u.crypted_password != nil
		args = {[], &Kernel.++/2}
			|> oper_if(u.uid,         ["--uid",      "#{u.uid}"])
			|> oper_if(u.gid,         ["--gid",      "#{u.gid}"])
			|> oper_if(u.comment,     ["--comment",  u.comment])
			|> oper_if(have_password, ["--password", u.crypted_password])
			|> oper_if(true,          ["--shell",    u.shell])
			|> oper_if(true,          ["--home-dir", u.home])
			|> oper_if(true,          ["--create-home"])
			|> elem(0)
		# We don't check the output of useradd because it can say a lot of things, e.g.:
		# 
		# useradd: warning: the home directory already exists.
		# Not copying any file from skel directory into it.
		#
		# or
		#
		# sent invalidate(passwd) request, exiting
		# sent invalidate(group) request, exiting
		# sent invalidate(passwd) request, exiting
		# sent invalidate(group) request, exiting
		{_, 0} = System.cmd("useradd", args ++ ["--", u.name], stderr_to_stdout: true)
	end

	defp authorized_keys_unit(u) do
		%UserAuthorizedKeys{name: u.name, authorized_keys: u.authorized_keys}
	end

	def package_dependencies(_, _release), do: ["passwd"]
end


defmodule Converge.UserDisabled do
	@moduledoc """
	A user is disabled.  Cannot converge if the user doesn't exist.

	We disable, instead of delete, users that are no longer needed, because
	adduser and useradd recycle UIDs, and with this recycling, new users gain
	access to files left behind by deleted users.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.UserDisabled do
	def met?(u, _ctx) do
		user = UserUtil.get_users()[u.name]
		cond do
			user == nil -> false
			# if no :locked key, /etc/shadow entry is missing; assume locked
			user[:locked] in [nil, true] and user.shell == "/bin/false" -> true
			true -> false
		end
	end

	def meet(u, _) do
		{out, status} = System.cmd("usermod", [
			"--lock",
			"--shell",   "/bin/false",
			"--comment", "Disabled but kept to prevent UID recycling",
			u.name
		], stderr_to_stdout: true)
		no_such_user_error = ~s(usermod: user '#{u.name}' does not exist\n)
		case {out, status} do
			# Don't check the output here because it can output things like:
			#
			# sent invalidate(passwd) request, exiting
			# sent invalidate(group) request, exiting
			# sent invalidate(passwd) request, exiting
			# sent invalidate(group) request, exiting
			{_,                   0} -> nil
			{^no_such_user_error, 6} -> raise(UnitError, "User #{inspect u.name} does not exist")
		end
	end

	def package_dependencies(_, _release), do: ["passwd"]
end


defmodule Converge.UserMissing do
	@moduledoc """
	A user is not present in the user database.

	Because adduser and useradd recycle UIDs, you should almost never use this,
	except for testing, or for deleting users that have no files remaining on
	the the filesystem.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.UserMissing do
	def met?(u, _ctx) do
		users = UserUtil.get_users()
		not Map.has_key?(users, u.name)
	end

	def meet(u, _) do
		{"", 0} = System.cmd("userdel", ["--", u.name])
	end

	def package_dependencies(_, _release), do: ["passwd"]
end


defmodule Converge.RegularUsersPresent do
	@moduledoc """
	A set of regular (i.e. non-system) users exist in the user database.

	Use this instead of `UserPresent`, `UserDisabled`, or `UserMissing`,
	because it will automatically disable users that are no longer defined here.

	Regular users that currently exist, but should not, will be disabled.

	`users` should be a list of `Converge.User` structs.
	"""
	@enforce_keys [:users]
	defstruct users: nil
end

defimpl Unit, for: Converge.RegularUsersPresent do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	def make_unit(u) do
		uid_min = UserUtil.get_uid_min()
		uid_max = UserUtil.get_uid_max()

		userpresent_units = for user <- u.users do
			if user.uid != nil && not (user.uid >= uid_min && user.uid <= uid_max) do
				raise(UnitError,
					"""
					UID for regular user #{inspect user.name} must be \
					>= #{uid_min} and <= #{uid_max}; was #{inspect user.uid}
					""")
			end
			user_to_userpresent(user)
		end

		# Usernames of existing regular users in the user database
		regular_user_usernames =
			UserUtil.get_users()
			|> Enum.filter(fn {_, user} ->
					user.uid >= uid_min &&
					user.uid <= uid_max end)
			|> Enum.map(fn {name, _} -> name end)
			|> MapSet.new

		# Usernames of regular users we want to exist
		wanted_user_usernames =
			u.users
			|> Enum.map(fn user -> user.name end)
			|> MapSet.new

		userdisabled_units =
			MapSet.difference(regular_user_usernames, wanted_user_usernames)
			|> Enum.map(fn name -> %UserDisabled{name: name} end)

		%Converge.All{units: userpresent_units ++ userdisabled_units}
	end

	defp user_to_userpresent(user) do
		%UserPresent{
			name:             user.name,
			uid:              user.uid,
			gid:              user.gid,
			comment:          user.comment,
			home:             user.home,
			shell:            user.shell,
			locked:           user.locked,
			crypted_password: user.crypted_password,
			authorized_keys:  user.authorized_keys,
		}
	end

	def package_dependencies(_, release) do
		Converge.Unit.package_dependencies(%{__struct__: UserPresent}, release) ++
		Converge.Unit.package_dependencies(%{__struct__: UserDisabled}, release)
	end
end

# TODO: ExtraGroupsPresent
# does not control a user's primary group
# does not control nogroup
# does not control system groups

# <ivan> usermod -G sets the groups for a user, but I want to set users for a group
# (because there may be system-managed groups that I'm not aware of)
