alias Converge.{All, Unit, Runner}
alias Converge.TestHelpers.{ConvergeableUnit, AlreadyConvergedUnit, SilentReporter}

defmodule Converge.AllTest do
	use ExUnit.Case

	test "All.met? runs met? on child units until one returns false" do
		u1  = ConvergeableUnit.new()
		u2  = ConvergeableUnit.new()
		u3  = ConvergeableUnit.new()
		all = %All{units: [%AlreadyConvergedUnit{}, u1, u2, u3]}
		Unit.met?(all)

		assert ConvergeableUnit.get_met_count(u1) == 1
		assert ConvergeableUnit.get_met_count(u2) == 0
		assert ConvergeableUnit.get_met_count(u3) == 0
	end

	test "can converge an All" do
		u1  = ConvergeableUnit.new()
		u2  = ConvergeableUnit.new()
		u3  = ConvergeableUnit.new()
		all = %All{units: [u1, u2, u3]}
		Runner.converge(all, SilentReporter)

		# met? is run 3-4 times on the child units:
		# 1. by All.met? (Only on the first unit, which returns false,
		#    causing it to skip the rest.)
		# 2. by Runner.converge, before `meet`
		# 3. by Runner.converge, after `meet`
		# 4. by All.met? again
		assert ConvergeableUnit.get_met_count(u1) == 4
		assert ConvergeableUnit.get_met_count(u2) == 3
		assert ConvergeableUnit.get_met_count(u3) == 3
	end
end
