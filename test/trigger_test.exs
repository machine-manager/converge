alias Converge.{Unit, Runner, Context, UnitError, AfterMeet, BeforeMeet}
alias Converge.TestHelpers.{FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit, TestingContext}

defmodule Converge.Runner.AfterMeetTest do
	use ExUnit.Case, async: true

	test "AfterMeet does not call trigger function if meet was not called" do
		acu = %AlreadyConvergedUnit{}
		t   = %AfterMeet{unit: acu, trigger: fn -> raise(UnitError, "from trigger") end}
		Runner.converge(t, TestingContext.get_context())
	end

	test "AfterMeet does not call trigger function if wrapped unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		t   = %AfterMeet{unit: ftc, trigger: fn -> raise(UnitError, "from trigger") end}
		# Make sure we got "Failed to converge", not "from trigger"
		assert_raise(
			UnitError, ~r/^Failed to converge: /,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end

	test "AfterMeet calls trigger function if meet was called" do
		cu = ConvergeableUnit.new()
		t  = %AfterMeet{unit: cu, trigger: fn -> raise(UnitError, "from trigger") end}
		assert_raise(
			UnitError, ~r/^from trigger$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end

	def is_context?(%Context{}), do: true
	def is_context?(_), do: false

	test "AfterMeet calls trigger function with context if trigger has arity of 1" do
		cu = ConvergeableUnit.new()
		t  = %AfterMeet{unit: cu, trigger: fn ctx ->
			if is_context?(ctx) do
				raise(UnitError, "object is Context")
			end
		end}
		assert_raise(
			UnitError, ~r/^object is Context$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end
end


defmodule Converge.Runner.BeforeMeetTest do
	use ExUnit.Case, async: true

	test "BeforeMeet does not call trigger function if meet was not called" do
		acu = %AlreadyConvergedUnit{}
		t   = %BeforeMeet{unit: acu, trigger: fn -> raise(UnitError, "from trigger") end}
		Runner.converge(t, TestingContext.get_context())
	end

	test "BeforeMeet does not call meet if trigger function raises an error" do
		ftc = %FailsToConvergeUnit{}
		t   = %BeforeMeet{unit: ftc, trigger: fn -> raise(UnitError, "from trigger") end}
		# Make sure we got "from trigger", not "Failed to converge"
		assert_raise(
			UnitError, ~r/^from trigger$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end

	def is_context?(%Context{}), do: true
	def is_context?(_), do: false

	test "BeforeMeet calls trigger function with context if trigger has arity of 1" do
		cu = ConvergeableUnit.new()
		t  = %BeforeMeet{unit: cu, trigger: fn ctx ->
			if is_context?(ctx) do
				raise(UnitError, "object is Context")
			end
		end}
		assert_raise(
			UnitError, ~r/^object is Context$/,
			fn -> Runner.converge(t, TestingContext.get_context()) end
		)
	end
end
