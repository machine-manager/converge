alias Converge.{UserUtil, Runner, UnitError}
alias Converge.TestHelpers.TestingContext

defmodule Converge.UserUtilTest do
	use ExUnit.Case, async: true

	test ~s(UserUtil.get_users includes "root") do
		users = UserUtil.get_users()
		assert Map.has_key?(users, "root")
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
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, TestingContext.get_context())
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent",
			shell:   "/bin/bash",
		}, TestingContext.get_context())
	end

	test "can create a user with a specific uid, locked, crypted_password, authorized_keys" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, TestingContext.get_context())
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			uid:              2000,
			locked:           false,
			crypted_password: "$1$HK1.P14i$3uOXlDCZbK8TmSXWOO5cV/",
			authorized_keys:  ["ssh-rsa bogus-key name@host"],
		}, TestingContext.get_context())
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
			fn -> Runner.converge(u, TestingContext.get_context()) end
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
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end

	test "can change shell, home, comment, and crypted_password for a user that already exists" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, TestingContext.get_context())
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
		}, TestingContext.get_context())
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent-new-home",
			shell:            "/bin/zsh",
			comment:          "Delete me",
			crypted_password: "$1$PSLJ33JN$ZQ57z/KqQi.ttlw4fXlFD0",
		}, TestingContext.get_context())

		# comment and crypted_password are unchanged when not given
		Runner.converge(%Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent-new-home",
			shell:            "/bin/zsh",
		}, TestingContext.get_context())
		user = UserUtil.get_users()["converge-test-userpresent"]
		assert user.comment          == "Delete me"
		assert user.crypted_password == "$1$PSLJ33JN$ZQ57z/KqQi.ttlw4fXlFD0"
	end

	test "can not change uid" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, TestingContext.get_context())
		u = %Converge.UserPresent{
			name:             "converge-test-userpresent",
			home:             "/home/converge-test-userpresent",
			shell:            "/bin/bash",
			uid:              2000
		}
		Runner.converge(u, TestingContext.get_context())
		assert_raise UnitError, ~r"^Failed to converge", \
			fn -> Runner.converge(%Converge.UserPresent{u | uid: 2001}, TestingContext.get_context()) end
	end
end


defmodule Converge.UserDisabledTest do
	use ExUnit.Case, async: true

	test "raises UnitError if user doesn't exist" do
		u = %Converge.UserDisabled{name: "converge-test-userdisabled-never-existed"}
		assert_raise UnitError, ~r"^User .* does not exist", \
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end

	test "can disable an existing user" do
		name = "converge-test-userdisabled"
		Runner.converge(%Converge.UserPresent{
			name:             name,
			home:             "/home/#{name}",
			shell:            "/bin/zsh",
		}, TestingContext.get_context())
		Runner.converge(%Converge.UserDisabled{name: name}, TestingContext.get_context())
	end
end


defmodule Converge.UserMissingTest do
	use ExUnit.Case, async: true

	test "can converge when user does not exist" do
		u = %Converge.UserMissing{name: "converge-test-userdeleted-never-existed"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "can converge when user exists" do
		name = "converge-test-userdeleted"
		Runner.converge(%Converge.UserPresent{
			name:    name,
			home:    "/home/#{name}",
			shell:   "/bin/bash",
		}, TestingContext.get_context())

		Runner.converge(%Converge.UserMissing{name: name}, TestingContext.get_context())
	end
end


defmodule Converge.RegularUsersPresentTest do
	use ExUnit.Case, async: true

	test "creates multiple users as needed, and disables any users not given" do
		# Include the non-converge-tests users on the system, so that this
		# test doesn't disable them.
		users = get_non_converge_regular_users() ++ [
			%Converge.User{name: "converge-nsup-1", home: "/home/converge-nsup-1", shell: "/bin/zsh"},
			%Converge.User{name: "converge-nsup-2", home: "/home/converge-nsup-2", shell: "/bin/zsh"},
			%Converge.User{name: "converge-nsup-3", home: "/home/converge-nsup-3", shell: "/bin/zsh"},
		]
		u = %Converge.RegularUsersPresent{users: users}
		Runner.converge(u, TestingContext.get_context())
	end

	defp get_non_converge_regular_users() do
		uid_min = UserUtil.get_uid_min()
		uid_max = UserUtil.get_uid_max()
		UserUtil.get_users()
		|> Enum.filter(fn {_, user} -> user.uid >= uid_min && user.uid <= uid_max end)
		|> Enum.filter(fn {name, _} -> not String.starts_with?(name, "converge-") end)
		|> Enum.map(fn {name, user} -> %Converge.User{name: name, home: user.home, shell: user.shell} end)
	end

	test "raises UnitError if given a UID below the range of regular users" do
		user = %Converge.User{name: "converge-invalid", home: "/home/converge-invalid", shell: "/bin/zsh", uid: 0}
		u = %Converge.RegularUsersPresent{users: [user]}
		assert_raise UnitError, ~r"^UID for regular user",
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end

	test "raises UnitError if given a UID above the range of regular users" do
		uid_max = UserUtil.get_uid_max()
		user = %Converge.User{name: "converge-invalid", home: "/home/converge-invalid", shell: "/bin/zsh", uid: uid_max + 1}
		u = %Converge.RegularUsersPresent{users: [user]}
		assert_raise UnitError, ~r"^UID for regular user",
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end
end


defmodule Converge.UserAuthorizedKeysTest do
	use ExUnit.Case, async: true

	test "UserAuthorizedKeys" do
		u = %Converge.UserAuthorizedKeys{name: "_chrony", authorized_keys: ["ssh-rsa bogus"]}
		Runner.converge(u, TestingContext.get_context())
	end
end
