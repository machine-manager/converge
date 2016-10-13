import ExUnit.Assertions, only: [assert: 1, assert: 2]
alias Converge.Unit

defmodule Converge.TestHelpers.FailsToConvergeUnit do
	@moduledoc """
	A unit that doesn't converge, always returning met?() -> false
	"""
	defstruct []
end

defimpl Unit, for: Converge.TestHelpers.FailsToConvergeUnit do
	def meet(_, _) do
	end

	def met?(_) do
		false
	end
end


defmodule Converge.TestHelpers.AlreadyConvergedUnit do
	@moduledoc """
	A unit that is already converged, so meet() should not be called.
	"""
	defstruct []
end

defimpl Unit, for: Converge.TestHelpers.AlreadyConvergedUnit do
	def meet(_, _) do
		assert false, "unreachable"
	end

	def met?(_) do
		true
	end
end


defmodule Converge.TestHelpers.ConvergeableUnit do
	@moduledoc """
	A unit that returns met?() -> false until meet() is called.  Used
	for testing that met?() is called a second time after meet().
	"""
	defstruct pid: nil

	def new do
		{:ok, pid} = Agent.start_link(fn -> {false, 0} end)
		%Converge.TestHelpers.ConvergeableUnit{pid: pid}
	end

	def get_met_count(p) do
		Agent.get(p.pid, fn({_, met_count}) -> met_count end)
	end
end

defimpl Unit, for: Converge.TestHelpers.ConvergeableUnit do
	def meet(p, _) do
		Agent.update(p.pid, fn({_, met_count}) ->
			{true, met_count}
		end)
	end

	def met?(p) do
		Agent.get_and_update(p.pid, fn({has_met, met_count}) ->
			{has_met, {has_met, met_count + 1}}
		end)
	end
end


defmodule Converge.Runner.RunnerTest do
	use ExUnit.Case
	alias Converge.{Runner, UnitError}
	alias Converge.TestHelpers.{SilentReporter, FailsToConvergeUnit, AlreadyConvergedUnit, ConvergeableUnit}

	test "Runner.converge raises UnitError if Unit fails to converge" do
		ftc = %FailsToConvergeUnit{}
		rep = SilentReporter
		assert_raise(UnitError, ~r/^Failed to converge: /, fn -> Runner.converge(ftc, rep) end)
	end

	test "Runner.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedUnit{}
		rep = SilentReporter
		Runner.converge(acp, rep)
	end

	test "Runner.converge calls met? again after calling meet" do
		cp = ConvergeableUnit.new
		rep = SilentReporter
		Runner.converge(cp, rep)
		assert ConvergeableUnit.get_met_count(cp) == 2
	end
end
