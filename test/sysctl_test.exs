alias Converge.{Sysctl, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.SysctlTest do
	use ExUnit.Case, async: true

	test "no parameters" do
		u = %Sysctl{parameters: %{}}
		Runner.converge(u, TestingContext.get_context())
	end

	test "some integer and string parameters" do
		u = %Sysctl{parameters: %{
			"vm.dirty_background_ratio" => :rand.uniform(6),
			"vm.dirty_ratio" => "11",
			"vm.vfs_cache_pressure" => 25 + :rand.uniform(50),
			"net.core.default_qdisc" => "pfifo_fast",
		}}
		Runner.converge(u, TestingContext.get_context())
	end
end
