defmodule Converge.Runner.AfterMeetTest do
	use ExUnit.Case, async: true

	alias Converge.{Runner, Context, UnitError, AfterMeet}
	alias Converge.TestHelpers.{FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit, TestingContext}

	test "AfterMeet does not call trigger function if meet was not called" do
		acu = %AlreadyConvergedUnit{}
		t   = %AfterMeet{unit: acu, trigger: fn -> raise UnitError, message: "boom" end}
		Runner.converge(t, TestingContext.get_context())
	end

	test "AfterMeet does not call trigger function if wrapped unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		t   = %AfterMeet{unit: ftc, trigger: fn -> raise UnitError, message: "boom" end}
		# Make sure we got "Failed to converge", not "boom"
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end

	test "AfterMeet calls trigger function if meet was called" do
		cu = ConvergeableUnit.new()
		t  = %AfterMeet{unit: cu, trigger: fn -> raise UnitError, message: "boom" end}
		assert_raise(
			UnitError, ~r/^boom$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end

	def is_context?(%Context{}), do: true
	def is_context?(_), do: false

	test "AfterMeet calls trigger function with context if trigger has arity of 1" do
		cu = ConvergeableUnit.new()
		t  = %AfterMeet{unit: cu, trigger: fn ctx ->
			if is_context?(ctx) do
				raise UnitError, message: "boom"
			end
		end}
		assert_raise(
			UnitError, ~r/^boom$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end
end
