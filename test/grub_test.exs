alias Converge.{Grub, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.GrubTest do
	use ExUnit.Case, async: true

	test "default grub config" do
		u = %Grub{}
		Runner.converge(u, TestingContext.get_context())
	end
end
