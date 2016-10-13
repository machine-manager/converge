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

	def new() do
		{:ok, pid} = Agent.start_link(fn -> {false, 0} end)
		%Converge.TestHelpers.ConvergeableUnit{pid: pid}
	end

	def get_met_count(u) do
		Agent.get(u.pid, fn({_, met_count}) -> met_count end)
	end
end

defimpl Unit, for: Converge.TestHelpers.ConvergeableUnit do
	def meet(u, _) do
		Agent.update(u.pid, fn({_, met_count}) ->
			{true, met_count}
		end)
	end

	def met?(u) do
		Agent.get_and_update(u.pid, fn({has_met, met_count}) ->
			{has_met, {has_met, met_count + 1}}
		end)
	end
end


defmodule Converge.TestHelpers.SilentReporter do
	def running(_) do end
	def meeting(_) do end
	def already_met(_) do end
	def just_met(_) do end
	def failed(_) do end
	def done(_) do end
end

ExUnit.start()
