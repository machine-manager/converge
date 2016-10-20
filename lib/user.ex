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
		{name, %{crypted_password: crypted_password}}
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

defmodule Converge.UserEnabled do
	@enforce_keys [:name, :home, :shell]
	defstruct name: nil, uid: nil, gid: nil, comment: "", home: nil, shell: nil
end

defmodule Converge.UserDisabled do
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.UserDisabled do
	alias Converge.UserUtil

	def met?(u) do
		%{shell: shell} = UserUtil.get_users()[u.name]
		shell == "/bin/false"
	end

	def meet(u, rep) do

	end
end
