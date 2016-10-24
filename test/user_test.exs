alias Converge.{UserUtil, Runner, UnitError}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.UserUtilTest do
	use ExUnit.Case, async: true

	test "UserUtil.get_users has root" do
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
