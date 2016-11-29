alias Converge.Unit

defmodule Converge.All do
	@moduledoc """
	All units in `units` are satisfied.
	"""
	@enforce_keys [:units]
	defstruct units: []
end

defimpl Unit, for: Converge.All do
	def met?(u) do
		u.units
			|> Stream.map(&Unit.met?/1)
			|> Enum.all?
	end

	def meet(u, ctx) do
		for unit <- u.units do
			Converge.Runner.converge(unit, ctx)
		end
	end
end
