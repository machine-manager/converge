alias Converge.{UserUtil, Runner}
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
			shell:   "/bin/bash"
		}, SilentReporter)
	end

	test "can create a user with a specific uid" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent",
			shell:   "/bin/bash",
			uid:     2000
		}, SilentReporter)
	end

	test "can change shell, home, and comment for a user that already exists" do
		Runner.converge(%Converge.UserMissing{name: "converge-test-userpresent"}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent",
			shell:   "/bin/bash"
		}, SilentReporter)
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent-new-home",
			shell:   "/bin/zsh",
			comment: "Delete me"
		}, SilentReporter)

		# Comment is unchanged when not given
		Runner.converge(%Converge.UserPresent{
			name:    "converge-test-userpresent",
			home:    "/home/converge-test-userpresent-new-home",
			shell:   "/bin/zsh"
		}, SilentReporter)
		assert UserUtil.get_users()["converge-test-userpresent"].comment == "Delete me"
	end

	test "can not change uid or gid" do

	end

	# TODO: test that uid and gid is unchanged if not given
	# TODO: test that uid and gid is unchanged if given (errors out)
end
