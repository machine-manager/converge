alias Converge.{Runner, SystemdUnitStarted, SystemdUnitStopped, SystemdUnitEnabled, SystemdUnitDisabled}
alias Converge.TestHelpers.{TestingContext}

defmodule Converge.Runner.SystemdUnitStartedTest do
	use ExUnit.Case

	test "SystemdUnitStarted" do
		u = %SystemdUnitStarted{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.Runner.SystemdUnitStoppedTest do
	use ExUnit.Case

	test "SystemdUnitStopped" do
		u = %SystemdUnitStopped{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end
end


defmodule Converge.Runner.SystemdUnitEnabled do
	use ExUnit.Case

	test "SystemdUnitEnabled" do
		u = %SystemdUnitEnabled{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end
end


defmodule Converge.Runner.SystemdUnitDisabled do
	use ExUnit.Case

	test "SystemdUnitDisabled" do
		u = %SystemdUnitDisabled{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end
end
