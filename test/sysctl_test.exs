alias Converge.{Sysctl, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.SysctlTest do
	use ExUnit.Case, async: true

	test "no parameters" do
		u = %Sysctl{parameters: %{}}
		Runner.converge(u, TestingContext.get_context())
	end
end
