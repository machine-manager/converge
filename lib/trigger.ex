alias Converge.{Unit, Runner}

defmodule Converge.Trigger do
	@moduledoc """
	If meet() was run on `unit`, call `trigger`.
	"""
	@enforce_keys [:unit, :trigger]
	defstruct unit: nil, trigger: nil
end

defimpl Unit, for: Converge.Trigger do
	def met?(u) do
		Unit.met?(u.unit)
	end

	def meet(u, ctx) do
		modified = Runner.converge(u.unit, ctx)
		if modified do
			u.trigger.()
		end
	end
end
