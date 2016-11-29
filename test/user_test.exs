alias Converge.{UserUtil, Runner, UnitError}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.UserUtilTest do
	use ExUnit.Case, async: true

	test ~s(UserUtil.get_users includes "root") do
		users = UserUtil.get_users()
		assert users |> Map.has_key?("root")
	end

	test "UserUtil.get_users values include all the expected keys" do
		root = UserUtil.get_users()["root"]
		assert is_integer(root.uid)
		assert is_integer(root.gid)
		assert is_binary(root.comment)
		assert is_binary(root.home)
		assert is_binary(root.shell)
		assert is_binary(root.crypted_password)
	end

	test "UserUtil.get_uid_min returns an integer" do
		uid_min = UserUtil.get_uid_min()
		assert is_integer(uid_min)
	end

	test "UserUtil.get_uid_max returns an integer greater than get_uid_min" do
		uid_min = UserUtil.get_uid_min()
		uid_max = UserUtil.get_uid_max()
		assert is_integer(uid_max)
		assert uid_max > uid_min
	end
end


defmodule Converge.UserPresentTest do
	use ExUnit.Case, async: true

	test "can create a user that doesn't exist" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent",
			shell:   "/bin/bash",
		}, SilentReporter)
	end

	test "can create a user with a specific uid, locked, crypted_password" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			uid:              2000,
			locked:           false,
			crypted_password: "$1$HK1.P14i$3uOXlDCZbK8TmSXWOO5cV/",
		}, SilentReporter)
	end

	test "raises UnitError with helpful error when locked but crypted_password lacks '!'" do
		u = %Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			locked:           true,
			crypted_password: "$1$HK1.P14i$3uOXlDCZbK8TmSXWOO5cV/",
		}
		assert_raise UnitError, ~r"^Expected crypted_password to be locked",
			fn -> Runner.converge(u, SilentReporter) end
	end

	test "raises UnitError with helpful error when not locked but crypted_password has '!'" do
		u = %Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			locked:           false,
			crypted_password: "!$1$HK1.P14i$3uOXlDCZbK8TmSXWOO5cV/",
		}
		assert_raise UnitError, ~r"^Expected crypted_password to be unlocked",
			fn -> Runner.converge(u, SilentReporter) end
	end

	test "can change shell, home, comment, and crypted_password for a user that already exists" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
		}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent-new-home",
			shell:            "/bin/zsh",
			comment:          "Delete me",
			crypted_password: "$1$PSLJ33JN$ZQ57z/KqQi.ttlw4fXlFD0",
		}, SilentReporter)

		# comment and crypted_password are unchanged when not given
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent-new-home",
			shell:            "/bin/zsh",
		}, SilentReporter)
		user = UserUtil.get_users()["converge-test-userpresent"]
		assert user.comment          == "Delete me"
		assert user.crypted_password == "$1$PSLJ33JN$ZQ57z/KqQi.ttlw4fXlFD0"
	end

	test "can not change uid" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		u = %Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			uid:              2000
		}
		Runner.converge(u, SilentReporter)
		assert_raise UnitError, ~r"^Failed to converge", \
			fn -> Runner.converge(%Converge.UserPresent{u | uid: 2001}, SilentReporter) end
	end
end


defmodule Converge.UserDisabledTest do
	use ExUnit.Case, async: true

	test "raises UnitError if user doesn't exist" do
		u = %Converge.UserDisabled{name: "converge-test-userdisabled-never-existed"}
		assert_raise UnitError, ~r"^User .* does not exist", \
			fn -> Runner.converge(u, SilentReporter) end
	end

	test "can disable an existing user" do
		name = "converge-test-userdisabled"
		Runner.converge(%Converge.UserPresent{
			name:             name,
			home:             "/home/#{name}",
			shell:            "/bin/zsh",
		}, SilentReporter)
		Runner.converge(%Converge.UserDisabled{name: name}, SilentReporter)
	end
end


defmodule Converge.UserMissingTest do
	use ExUnit.Case, async: true

	test "can converge when user does not exist" do
		u = %Converge.UserMissing{name: "converge-test-userdeleted-never-existed"}
		Runner.converge(u, SilentReporter)
	end

	test "can converge when user exists" do
		name = "converge-test-userdeleted"
		Runner.converge(%Converge.UserPresent{
			name:    name,
			home:    "/home/#{name}",
			shell:   "/bin/bash",
		}, SilentReporter)

		Runner.converge(%Converge.UserMissing{name: name}, SilentReporter)
	end
end


defmodule Converge.NonSystemUsersPresentTest do
	use ExUnit.Case, async: true

	test "creates multiple users as needed, and disables any users not given" do
		# Include the non-converge-tests users on the system, so that this
		# test doesn't disable them.
		users = get_non_converge_non_system_users() ++ [
			%Converge.User{name: "converge-nsup-1", home: "/home/converge-nsup-1", shell: "/bin/zsh"},
			%Converge.User{name: "converge-nsup-2", home: "/home/converge-nsup-2", shell: "/bin/zsh"},
			%Converge.User{name: "converge-nsup-3", home: "/home/converge-nsup-3", shell: "/bin/zsh"},
		]
		u = %Converge.NonSystemUsersPresent{users: users}
		Runner.converge(u, SilentReporter)
	end

	defp get_non_converge_non_system_users() do
		uid_min = UserUtil.get_uid_min()
		uid_max = UserUtil.get_uid_max()
		UserUtil.get_users()
		|> Enum.filter(fn {_, user} ->
				user.uid >= uid_min &&
				user.uid <= uid_max end)
		|> Enum.filter(fn {name, _} ->
				name |> String.starts_with?("converge-") |> Kernel.not end)
		|> Enum.map(fn {name, user} ->
				%Converge.User{name: name, home: user.home, shell: user.shell} end)
	end

	test "raises UnitError if given a UID below the range of non-system users" do
		user = %Converge.User{name: "converge-invalid", home: "/home/converge-invalid", shell: "/bin/zsh", uid: 0}
		u = %Converge.NonSystemUsersPresent{users: [user]}
		assert_raise UnitError, ~r"^UID for non-system user",
			fn -> Runner.converge(u, SilentReporter) end
	end

	test "raises UnitError if given a UID above the range of non-system users" do
		uid_max = UserUtil.get_uid_max()
		user = %Converge.User{name: "converge-invalid", home: "/home/converge-invalid", shell: "/bin/zsh", uid: uid_max + 1}
		u = %Converge.NonSystemUsersPresent{users: [user]}
		assert_raise UnitError, ~r"^UID for non-system user",
			fn -> Runner.converge(u, SilentReporter) end
	end
end
