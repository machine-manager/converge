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

defmodule IdempolicyTest do
	use ExUnit.Case
	doctest Idempolicy

	test "Idempolicy.converge raises ConvergeError if policy fails to converge" do
		ftc = %FailsToConvergePolicy{}
		rep = Reporter
		assert_raise(ConvergeError, ~r/Failed to converge: /, fn -> Idempolicy.converge(ftc, rep) end)
	end
end
