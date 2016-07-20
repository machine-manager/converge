import ExUnit.Assertions, only: [assert: 1, assert: 2]

defmodule FailsToConvergePolicy do
	defstruct []
end

defimpl Converge, for: FailsToConvergePolicy do
	def met?(_) do
		false
	end

	def meet(_) do
	end
end


defmodule AlreadyConvergedPolicy do
	defstruct []
end

defimpl Converge, for: AlreadyConvergedPolicy do
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
		Agent.get(p.pid, fn({has_met, met_count}) -> met_count end)
	end
end

defimpl Converge, for: ConvergeablePolicy do
	def met?(p) do
		Agent.get_and_update(p.pid, fn({has_met, met_count}) -> {has_met, {has_met, met_count + 1}} end)
	end

	def meet(p) do
		Agent.update(p.pid, fn({has_met, met_count}) -> {true, met_count} end)
	end
end


defmodule SilentReporter do
	def running(_) do end
	def converged(_) do end
	def failed(_) do end
end

defmodule IdempolicyTest do
	use ExUnit.Case
	doctest Idempolicy

	test "Idempolicy.converge raises ConvergeError if policy fails to converge" do
		ftc = %FailsToConvergePolicy{}
		rep = SilentReporter
		assert_raise(ConvergeError, ~r/^Failed to converge: /, fn -> Idempolicy.converge(ftc, rep) end)
	end

	test "Idempolicy.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedPolicy{}
		rep = SilentReporter
		Idempolicy.converge(acp, rep)
	end

	test "Idempolicy.converge calls met? again after calling meet" do
		cp = ConvergeablePolicy.new
		rep = SilentReporter
		Idempolicy.converge(cp, rep)
		assert ConvergeablePolicy.get_met_count(cp) == 2
	end
end
