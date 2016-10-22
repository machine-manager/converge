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


defmodule Converge.UserPresent do
	def "can create a user that doesn't exist" do
		Runner.converge(%Converge.UserDeleted{name: "converge-test-userpresent"})
		Runner.converge(%Converge.UserPresent{
			name:  "converge-test-userpresent",
			home:  "/home/converge-test-userpresent",
			shell: "/bin/bash"
		})
	end
	# TODO: test that comment is unchanged if not given
	# TODO: test that uid and gid is unchanged if not given
	# TODO: test that uid and gid is unchanged if given (errors out)
end
