alias Converge.{Runner, SystemdUnitStarted, SystemdUnitStopped}
alias Converge.TestHelpers.{TestingContext}

defmodule Converge.Runner.SystemdUnitStartedTest do
	use ExUnit.Case

	test "SystemdUnitStarted" do
		u = %SystemdUnitStarted{name: "chrony"}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.Runner.SystemdUnitStoppedTest do
	use ExUnit.Case

	test "SystemdUnitStopped" do
		u = %SystemdUnitStopped{name: "chrony"}
		Runner.converge(u, TestingContext.get_context())
	end
end
