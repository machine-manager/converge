alias Converge.{Unit, Runner}

defmodule Converge.AfterMeet do
	@moduledoc """
	Wraps a unit to call anonymous function `trigger` after a `meet` on `unit`.
	"""
	@enforce_keys [:unit, :trigger]
	defstruct unit: nil, trigger: nil
end

defimpl Unit, for: Converge.AfterMeet do
	def met?(u, ctx) do
		Runner.met?(u.unit, ctx)
	end

	def meet(u, ctx) do
		# Instead of calling Unit.meet directly (which would save some redundant
		# met? calls), call Runner.converge to ensure that the trigger is not run
		# if the wrapped unit fails to converge.
		Runner.converge(u.unit, ctx)
		{:arity, arity} = Function.info(u.trigger, :arity)
		case arity do
			0 -> u.trigger.()
			1 -> u.trigger.(ctx)
		end
	end

	def package_dependencies(_, _release), do: []
end


defmodule Converge.BeforeMeet do
	@moduledoc """
	Wraps a unit to call anonymous function `trigger` before a `meet` on `unit`.
	"""
	@enforce_keys [:unit, :trigger]
	defstruct unit: nil, trigger: nil
end

defimpl Unit, for: Converge.BeforeMeet do
	def met?(u, ctx) do
		Runner.met?(u.unit, ctx)
	end

	def meet(u, ctx) do
		{:arity, arity} = Function.info(u.trigger, :arity)
		case arity do
			0 -> u.trigger.()
			1 -> u.trigger.(ctx)
		end
		Runner.converge(u.unit, ctx)
	end

	def package_dependencies(_, _release), do: []
end
