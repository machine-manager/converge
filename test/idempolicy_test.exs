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

defmodule SilentReporter do
	def running(p) do end
	def converged(_) do end
	def failed(_) do end
end

defmodule IdempolicyTest do
	use ExUnit.Case
	doctest Idempolicy

	test "Idempolicy.converge raises ConvergeError if policy fails to converge" do
		ftc = %FailsToConvergePolicy{}
		rep = SilentReporter
		assert_raise(ConvergeError, ~r/Failed to converge: /, fn -> Idempolicy.converge(ftc, rep) end)
	end

	test "Idempolicy.converge doesn't call meet() if met? returns true" do
		acp = %AlreadyConvergedPolicy{}
		rep = SilentReporter
		Idempolicy.converge(acp, rep)
	end
end
