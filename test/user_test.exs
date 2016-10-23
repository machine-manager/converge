alias Converge.{UserUtil, Runner, UnitError}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.UserUtilTest do
	use ExUnit.Case

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
	use ExUnit.Case

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

	test "raises UnitError with helpful error when locked but crypted_password lacks !" do
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

	test "raises UnitError with helpful error when not locked but crypted_password has !" do
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

	test "can not change uid or gid" do

	end

	# TODO: test that uid and gid is unchanged if not given
	# TODO: test that uid and gid is unchanged if given (errors out)
end
