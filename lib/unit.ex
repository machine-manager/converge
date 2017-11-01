defprotocol Converge.Unit do
	@doc """
	Returns `true` if the current state is the desired state
	"""
	def met?(u, ctx)

	@doc """
	Changes some state in a way that would satisfy `met?`
	"""
	def meet(u, ctx)

	@doc """
	Takes a Linux distribution release name as an atom and returns a list of
	packages the unit requires to function.

	The implementation must not vary results based on the values in the unit
	struct: callers can call package_dependencies with a dummy struct that
	is missing all keys (even ones listed in @enforce_keys).
	"""
	def package_dependencies(u, release)
end

defmodule Converge.UnitError do
	defexception message: "met? returned false after running meet"
end
