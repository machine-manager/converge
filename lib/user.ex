defmodule Converge.UserUtil do
	defp passwd_line_to_tuple(line) do
		[name, "x", uid_s, gid_s, comment, home, shell] = String.split(line, ":")
		{uid, ""} = Integer.parse(uid_s)
		{gid, ""} = Integer.parse(gid_s)
		{name, %{uid: uid, gid: gid, comment: comment, home: home, shell: shell}}
	end

	def get_users() do
		File.read!("/etc/passwd")
			|> String.trim_trailing("\n")
			|> String.split("\n")
			|> Enum.map(&passwd_line_to_tuple/1)
			|> Enum.into(%{})
	end
end

defmodule Converge.UserExists do
	@enforce_keys [:name]
	defstruct name: nil
end
