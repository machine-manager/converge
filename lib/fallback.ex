alias Converge.{Unit, UnitError, Runner}

defmodule Converge.Fallback do
	@moduledoc """
	Converge `primary`, but if it fails to converge or raises `UnitError`,
	converge `fallback` instead.

	`met?` returns `true` if either `primary` or `fallback` is met.
	"""
	@enforce_keys [:primary, :fallback]
	defstruct primary: nil, fallback: nil
end

defimpl Unit, for: Converge.Fallback do
	def met?(u, ctx) do
		Runner.met?(u.primary, ctx) or Runner.met?(u.fallback, ctx)
	end

	def meet(u, ctx) do
		try do
			Runner.converge(u.primary, ctx)
		rescue
			_ in UnitError ->
				Runner.converge(u.fallback, ctx)
		end
	end
end
