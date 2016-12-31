defprotocol Converge.Unit do
	@doc "Returns `true` if the current state is the desired state"
	def met?(u, ctx)

	@doc "Changes some state in a way that would satisfy `met?`"
	def meet(u, ctx)
end

defmodule Converge.UnitError do
	defexception message: "met? returned false after running meet"
end
