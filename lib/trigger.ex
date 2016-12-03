alias Converge.{Unit, Runner}

defmodule Converge.Trigger do
	@moduledoc """
	Wraps a unit to call anonymous function `trigger` only after `meet`.
	"""
	@enforce_keys [:unit, :trigger]
	defstruct unit: nil, trigger: nil
end

defimpl Unit, for: Converge.Trigger do
	def met?(u) do
		Unit.met?(u.unit)
	end

	def meet(u, ctx) do
		# Use Unit.meet directly instead of Runner.converge to avoid two extra
		# redundant calls to Unit.met?(u.unit).  Effectively, we augment the unit
		# instead of converging a child unit.
		Unit.meet(u.unit, ctx)
		u.trigger.()
	end
end
