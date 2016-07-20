defmodule FailsToConvergePolicy do
	defstruct []
end

defimpl Converge, for: FailsToConvergePolicy do
	def met?(_) do
		false
	end

	def meet(_) do
	end
end

defmodule AlreadyConvergedPolicy do
	defstruct []
end

defimpl Converge, for: AlreadyConvergedPolicy do
	import ExUnit.Assertions, only: [assert: 1, assert: 2]

	def met?(_) do
		true
	end

	def meet(_) do
		assert false, "unreachable"
	end
end

defmodule IdempolicyTest do
	use ExUnit.Case
	doctest Idempolicy

	test "Idempolicy.converge raises ConvergeError if policy fails to converge" do
		ftc = %FailsToConvergePolicy{}
		rep = Reporter
		assert_raise(ConvergeError, ~r/Failed to converge: /, fn -> Idempolicy.converge(ftc, rep) end)
	end

	test "Idempolicy.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedPolicy{}
		rep = Reporter
		Idempolicy.converge(acp, rep)
	end
end
