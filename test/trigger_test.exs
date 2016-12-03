defmodule Converge.Runner.TriggerTest do
	use ExUnit.Case, async: true

	alias Converge.{Runner, UnitError, Trigger}
	alias Converge.TestHelpers.{AlreadyConvergedUnit, ConvergeableUnit, TestingContext}

	test "Trigger does not call trigger function if meet was not called" do
		acu = %AlreadyConvergedUnit{}
		t   = %Trigger{unit: acu, trigger: fn -> raise UnitError, message: "boom" end}
		Runner.converge(t, TestingContext.get_context())
	end

	test "Trigger calls trigger function if meet was called" do
		cu = ConvergeableUnit.new()
		t  = %Trigger{unit: cu, trigger: fn -> raise UnitError, message: "boom" end}
		assert_raise(
			UnitError, ~r/^boom$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end
end
