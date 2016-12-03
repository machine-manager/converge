alias Converge.{Assert, Unit, UnitError}
alias Converge.TestHelpers.ConvergeableUnit

defmodule Converge.AssertTest do
	use ExUnit.Case, async: true

	test "Assert.met? runs met? on child unit" do
		u1  = ConvergeableUnit.new()
		ass = %Assert{unit: u1}
		Unit.met?(ass)
		assert ConvergeableUnit.get_met_count(u1) == 1
		Unit.met?(ass)
		assert ConvergeableUnit.get_met_count(u1) == 2
	end

	test "Assert.meet always raises UnitError" do
		u1  = ConvergeableUnit.new()
		ass = %Assert{unit: u1}
		assert_raise(UnitError, fn -> Unit.meet(ass, nil) end)
	end
end
