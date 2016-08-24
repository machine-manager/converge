defprotocol Converge.Unit do
	@doc "Returns true if the current state is the desired state"
	def met?(p)

	@doc "Changes some state in a way that would satisfy met?"
	def meet(p)
end

defmodule Converge.UnitError do
	defexception message: "met? returned false after running meet"
end
