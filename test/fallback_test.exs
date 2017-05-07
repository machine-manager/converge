alias Converge.{Fallback, Runner, Unit, UnitError}
alias Converge.TestHelpers.{ConvergeableUnit, AlreadyConvergedUnit, FailsToConvergeUnit, TestingContext}

defmodule Converge.FallbackTest do
	use ExUnit.Case, async: true

	test "Fallback with primary already converged" do
		ctx = TestingContext.get_context()
		fb  = %Fallback{primary: %AlreadyConvergedUnit{}, fallback: nil}
		Runner.converge(fb, ctx)
	end

	test "Fallback with primary can converge" do
		ctx = TestingContext.get_context()
		u1  = ConvergeableUnit.new()
		u2  = ConvergeableUnit.new()
		fb  = %Fallback{primary: u1, fallback: u2}
		Runner.converge(fb, ctx)
		assert Unit.met?(u1, ctx) == true
		assert Unit.met?(u2, ctx) == false
	end

	test "Fallback with primary that fails to converge" do
		ctx = TestingContext.get_context()
		u2  = ConvergeableUnit.new()
		fb  = %Fallback{primary: %FailsToConvergeUnit{}, fallback: u2}
		Runner.converge(fb, ctx)
		assert Unit.met?(u2, ctx) == true
	end

	test "Fallback with primary and fallback that fail to converge" do
		ctx = TestingContext.get_context()
		fb  = %Fallback{primary: %FailsToConvergeUnit{}, fallback: %FailsToConvergeUnit{}}
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(fb, ctx) end
		)
	end
end
