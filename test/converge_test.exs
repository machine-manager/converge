defmodule Converge.Runner.RunnerTest do
	use ExUnit.Case, async: true

	alias Converge.{Runner, UnitError}
	alias Converge.TestHelpers.{FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit, TestingContext}

	test "Runner.converge raises UnitError if Unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(ftc, TestingContext.get_context()) end
		)
	end

	test "Runner.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedUnit{}
		Runner.converge(acp, TestingContext.get_context())
	end

	test "Runner.converge calls met? again after calling meet" do
		cp = ConvergeableUnit.new()
		Runner.converge(cp, TestingContext.get_context())
		assert ConvergeableUnit.get_met_count(cp) == 2
	end
end
