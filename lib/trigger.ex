alias Converge.{Unit, Runner}

defmodule Converge.Trigger do
	@moduledoc """
	Wraps a unit to call anonymous function `trigger` after a `meet`.
	"""
	@enforce_keys [:unit, :trigger]
	defstruct unit: nil, trigger: nil
end

defimpl Unit, for: Converge.Trigger do
	def met?(u, ctx) do
		Runner.met?(u.unit, ctx)
	end

	def meet(u, ctx) do
		# Instead of calling Unit.meet directly (which would save some redundant
		# met? calls), call Runner.converge to ensure that the trigger is not run
		# if the wrapped unit fails to converge.
		Runner.converge(u.unit, ctx)
		u.trigger.()
	end
end
