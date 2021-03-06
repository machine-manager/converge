alias Converge.{All, Runner}
alias Converge.TestHelpers.{ConvergeableUnit, AlreadyConvergedUnit, TestingContext}

defmodule Converge.AllTest do
	use ExUnit.Case, async: true

	test "All.met? runs met? on child units until one returns false" do
		u1  = ConvergeableUnit.new()
		u2  = ConvergeableUnit.new()
		u3  = ConvergeableUnit.new()
		all = %All{units: [%AlreadyConvergedUnit{}, u1, u2, u3]}
		Runner.met?(all, TestingContext.get_context())

		assert ConvergeableUnit.get_met_count(u1) == 1
		assert ConvergeableUnit.get_met_count(u2) == 0
		assert ConvergeableUnit.get_met_count(u3) == 0
	end

	test "can converge an All" do
		u1  = ConvergeableUnit.new()
		u2  = ConvergeableUnit.new()
		u3  = ConvergeableUnit.new()
		all = %All{units: [u1, u2, u3]}
		Runner.converge(all, TestingContext.get_context())

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

	test "inspect shows the number of units, not the units themselves" do
		u1 = ConvergeableUnit.new()

		assert inspect(%All{units: [      ]}) == "%Converge.All{0 units}"
		assert inspect(%All{units: [u1    ]}) == "%Converge.All{1 unit}"
		assert inspect(%All{units: [u1, u1]}) == "%Converge.All{2 units}"
	end
end
