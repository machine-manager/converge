alias Converge.{Unit, UnitError, Runner}

defmodule Converge.Assert do
	@moduledoc """
	This passes `met?` through to another unit, but always throws an exception
	on `meet()` instead of passing it through to that unit.

	This allows you to use another Unit as if it were an "assert".
	"""
	@enforce_keys [:unit]
	defstruct unit: nil
end

defimpl Unit, for: Converge.Assert do
	def met?(u, ctx) do
		Runner.met?(u.unit, ctx)
	end

	def meet(u, _) do
		raise(UnitError, "meet() called on an Assert: #{inspect u}")
	end
end
