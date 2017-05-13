alias Gears.FileUtil
alias Converge.{Unit, Runner}

defmodule Converge.Redo do
	@moduledoc """
	Wraps a unit to force a call to `meet` if a marker file exists.
	The marker file is created when converge on the unit raises any error,
	and removed when it converges without error.

	Useful in combination with `AfterMeet` to force the re-run of a trigger if
	the trigger failed last time.
	"""
	@enforce_keys [:marker, :unit]
	defstruct marker: nil, unit: nil
end

defimpl Unit, for: Converge.Redo do
	def met?(u, ctx) do
		not File.regular?(u.marker) and Runner.met?(u.unit, ctx)
	end

	def meet(u, ctx) do
		File.mkdir_p!(Path.dirname(u.marker))
		File.touch!(u.marker)
		Runner.converge(u.unit, ctx, true)
		FileUtil.rm_f!(u.marker)
	end
end
