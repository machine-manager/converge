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
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		len = length(u.units)
		concat([
			color("%Converge.All{", :map, opts),
			counted_noun(len, "unit", "units"),
			color("}",              :map, opts)
		])
	end
end
