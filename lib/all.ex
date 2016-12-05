alias Converge.{Unit, Runner}

defmodule Converge.All do
	@moduledoc """
	All units in `units` are satisfied.

	If any units conflict with each other, `All.met?` will return `false` when
	called a second time by `Runner.converge`.
	"""
	@enforce_keys [:units]
	defstruct units: []
end

defimpl Unit, for: Converge.All do
	def met?(u, ctx) do
		u.units
		|> Stream.map(&(Runner.met?(&1, ctx)))
		|> Enum.all?
	end

	def meet(u, ctx) do
		for unit <- u.units do
			Runner.converge(unit, ctx)
		end
	end
end

defimpl Inspect, for: Converge.All do
	def inspect(u, _opts) do
		len  = length(u.units)
		word = case len do
			1 -> "unit"
			_ -> "units"
		end
		"%Converge.All{#{len} #{word}}"
	end
end
