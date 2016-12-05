alias Converge.{Assert, Unit, UnitError, Runner}
alias Converge.TestHelpers.{ConvergeableUnit, TestingContext}

defmodule Converge.AssertTest do
	use ExUnit.Case, async: true

	test "Assert.met? runs met? on child unit" do
		u1  = ConvergeableUnit.new()
		ass = %Assert{unit: u1}
		ctx = TestingContext.get_context()
		Runner.met?(ass, ctx)
		assert ConvergeableUnit.get_met_count(u1) == 1
		Runner.met?(ass, ctx)
		assert ConvergeableUnit.get_met_count(u1) == 2
	end

	test "Assert.meet always raises UnitError" do
		u1  = ConvergeableUnit.new()
		ass = %Assert{unit: u1}
		ctx = TestingContext.get_context()
		assert_raise(UnitError, fn -> Unit.meet(ass, ctx) end)
	end
end
