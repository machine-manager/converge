alias Converge.{Sysfs, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.SysfsTest do
	use ExUnit.Case, async: true

	defp cleanup() do
		# Our cleanup assumes that nobody ever wants these enabled, at least in
		# the VM used for converge tests.
		u = %Sysfs{variables: %{
			"kernel/mm/transparent_hugepage/enabled" => "never",
			"kernel/mm/transparent_hugepage/defrag"  => "never",
		}}
		Runner.converge(u, TestingContext.get_context())
	end

	test "no variables" do
		u = %Sysfs{variables: %{}}
		try do
			Runner.converge(u, TestingContext.get_context())
		after
			cleanup()
		end
	end

	test "some variables" do
		u = %Sysfs{variables: %{
			"kernel/mm/transparent_hugepage/enabled" => Enum.random(["always", "madvise", "never"]),
			"kernel/mm/transparent_hugepage/defrag"  => Enum.random(["always", "madvise", "never"]),
		}}
		try do
			Runner.converge(u, TestingContext.get_context())
		after
			cleanup()
		end
	end
end
