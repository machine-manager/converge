defmodule Converge.Runner.RunnerTest do
	use ExUnit.Case
	alias Converge.{Runner, UnitError}
	alias Converge.TestHelpers.{SilentReporter, FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit}

	test "Runner.converge raises UnitError if Unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(ftc, SilentReporter) end
		)
	end

	test "Runner.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedUnit{}
		Runner.converge(acp, SilentReporter)
	end

	test "Runner.converge calls met? again after calling meet" do
		cp = ConvergeableUnit.new()
		Runner.converge(cp, SilentReporter)
		assert ConvergeableUnit.get_met_count(cp) == 2
	end
end
