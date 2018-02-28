alias Converge.{
	Runner, UnitError, SystemdUnitStarted, SystemdUnitStopped,
	SystemdUnitEnabled, SystemdUnitDisabled, EtcSystemdUnitFiles, FilePresent}
alias Converge.TestHelpers.{TestingContext}

defmodule Converge.Runner.SystemdUnitStartedTest do
	use ExUnit.Case

	test "SystemdUnitStarted" do
		# setup
		u = %SystemdUnitStopped{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %SystemdUnitStarted{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "SystemdUnitStarted on a nonexistent unit" do
		u = %SystemdUnitStarted{name: "nonexistent.service"}
		assert_raise(UnitError, ~r/Failed to start/, fn -> Runner.converge(u, TestingContext.get_context()) end)
	end
end


defmodule Converge.Runner.SystemdUnitStoppedTest do
	use ExUnit.Case

	test "SystemdUnitStopped" do
		# test
		u = %SystemdUnitStopped{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())

		# cleanup
		u = %SystemdUnitStarted{name: "chrony.service"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "SystemdUnitStopped on a nonexistent unit" do
		u = %SystemdUnitStopped{name: "nonexistent.service"}
		assert_raise(UnitError, ~r/Failed to stop/, fn -> Runner.converge(u, TestingContext.get_context()) end)
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


defmodule Converge.Runner.EtcSystemdUnitFiles do
	use ExUnit.Case

	test "EtcSystemdUnitFiles" do
		u = %EtcSystemdUnitFiles{units: [
			%FilePresent{path: "/etc/systemd/system/deleteme.service", mode: 0o644, content: ""},
		]}
		Runner.converge(u, TestingContext.get_context())

		u = %EtcSystemdUnitFiles{units: []}
		Runner.converge(u, TestingContext.get_context())
	end

	test "EtcSystemdUnitFiles with invalid path in unit" do
		u = %EtcSystemdUnitFiles{units: [
			%FilePresent{path: "/tmp/etc/systemd/system/deleteme.service", mode: 0o644, content: ""},
		]}
		assert_raise RuntimeError, ~r/ has path that does not start with /, fn ->
			Runner.converge(u, TestingContext.get_context())
		end
	end
end
