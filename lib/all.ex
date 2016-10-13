alias Converge.Unit

defmodule Converge.All do
	@enforce_keys [:units]
	defstruct units: []
end

defimpl Unit, for: Converge.All do
	def met?(u) do
		u.units
			|> Stream.map(&Unit.met?/1)
			|> Enum.all?
	end

	def meet(u, rep) do
		for unit <- u.units do
			Converge.Runner.converge(unit, rep)
		end
	end
end
