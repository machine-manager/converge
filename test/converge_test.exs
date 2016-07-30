import ExUnit.Assertions, only: [assert: 1, assert: 2]

defmodule FailsToConvergePolicy do
	defstruct []
end

defimpl Unit, for: FailsToConvergePolicy do
	def met?(_) do
		false
	end

	def meet(_) do
	end
end


defmodule AlreadyConvergedPolicy do
	defstruct []
end

defimpl Unit, for: AlreadyConvergedPolicy do
	def met?(_) do
		true
	end

	def meet(_) do
		assert false, "unreachable"
	end
end


defmodule ConvergeablePolicy do
	defstruct pid: nil

	def new do
		{:ok, pid} = Agent.start_link(fn -> {false, 0} end)
		%ConvergeablePolicy{pid: pid}
	end

	def get_met_count(p) do
		Agent.get(p.pid, fn({_, met_count}) -> met_count end)
	end
end

defimpl Unit, for: ConvergeablePolicy do
	def met?(p) do
		Agent.get_and_update(p.pid, fn({has_met, met_count}) ->
			{has_met, {has_met, met_count + 1}}
		end)
	end

	def meet(p) do
		Agent.update(p.pid, fn({_, met_count}) ->
			{true, met_count}
		end)
	end
end


defmodule ConvergeTest do
	use ExUnit.Case
	doctest Converge

	test "Converge.converge raises UnitError if policy fails to converge" do
		ftc = %FailsToConvergePolicy{}
		rep = SilentReporter
		assert_raise(UnitError, ~r/^Failed to converge: /, fn -> Converge.converge(ftc, rep) end)
	end

	test "Converge.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedPolicy{}
		rep = SilentReporter
		Converge.converge(acp, rep)
	end

	test "Converge.converge calls met? again after calling meet" do
		cp = ConvergeablePolicy.new
		rep = SilentReporter
		Converge.converge(cp, rep)
		assert ConvergeablePolicy.get_met_count(cp) == 2
	end
end
