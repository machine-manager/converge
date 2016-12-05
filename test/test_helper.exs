import ExUnit.Assertions, only: [assert: 2]
alias Converge.Unit

defmodule Converge.TestHelpers.FailsToConvergeUnit do
	@moduledoc """
	A unit that doesn't converge, always returning met?() -> false
	"""
	defstruct []
end

defimpl Unit, for: Converge.TestHelpers.FailsToConvergeUnit do
	def met?(_, _) do
		false
	end

	def meet(_, _) do
	end
end


defmodule Converge.TestHelpers.AlreadyConvergedUnit do
	@moduledoc """
	A unit that is already converged, so meet() should not be called.
	"""
	defstruct []
end

defimpl Unit, for: Converge.TestHelpers.AlreadyConvergedUnit do
	def met?(_, _) do
		true
	end

	def meet(_, _) do
		assert false, "unreachable"
	end
end


defmodule Converge.TestHelpers.ConvergeableUnit do
	@moduledoc """
	A unit that returns `met?()` -> `false` until `meet()` is called.
	Used for testing that `met?` is called a second time after `meet()`.
	"""
	defstruct pid: nil

	def new() do
		{:ok, pid} = Agent.start_link(fn -> {false, 0} end)
		%Converge.TestHelpers.ConvergeableUnit{pid: pid}
	end

	def get_met_count(u) do
		Agent.get(u.pid, fn({_, met_count}) -> met_count end)
	end
end

defimpl Unit, for: Converge.TestHelpers.ConvergeableUnit do
	def met?(u, _) do
		Agent.get_and_update(u.pid, fn({has_met, met_count}) ->
			{has_met, {has_met, met_count + 1}}
		end)
	end

	def meet(u, _) do
		Agent.update(u.pid, fn({_, met_count}) ->
			{true, met_count}
		end)
	end
end


defmodule Converge.TestHelpers.SilentReporter do
	defstruct []
	def new() do
		%Converge.TestHelpers.SilentReporter{}
	end
end

defimpl Converge.Reporter, for: Converge.TestHelpers.SilentReporter do
	def met?(_, _, _) do end
	def already_met(_, _, _) do end
	def should_meet(_, _, _) do end
	def just_met(_, _, _) do end
	def failed(_, _, _) do end
	def done(_, _, _) do end
end


defmodule Converge.TestHelpers.TestingContext do
	alias Converge.Context
	alias Converge.TestHelpers.SilentReporter

	def get_context() do
		%Context{reporter: SilentReporter.new(), run_meet: true}
	end
end

ExUnit.start()
