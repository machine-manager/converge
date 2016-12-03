defmodule Converge.Runner.RunnerTest do
	use ExUnit.Case, async: true

	alias Converge.{Runner, Context, UnitError}
	alias Converge.TestHelpers.{FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit, TestingContext}

	test "Runner.converge raises UnitError if Unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(ftc, TestingContext.get_context()) end
		)
	end

	test "Runner.converge doesn't call meet() if met? returns true" do
		acu = %AlreadyConvergedUnit{}
		Runner.converge(acu, TestingContext.get_context())
	end

	test "Runner.converge calls met? again after calling meet" do
		cu = ConvergeableUnit.new()
		Runner.converge(cu, TestingContext.get_context())
		assert ConvergeableUnit.get_met_count(cu) == 2
	end
end
