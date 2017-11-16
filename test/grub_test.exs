alias Converge.{Grub, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.GrubTest do
	use ExUnit.Case, async: true

	defp cleanup() do
		u = %Grub{}
		Runner.converge(u, TestingContext.get_context())
	end

	test "no options" do
		cleanup()
	end

	test "some options" do
		u = %Grub{timeout: 4, cmdline_normal_and_recovery: "quiet", gfxpayload: "640x480"}
		Runner.converge(u, TestingContext.get_context())
		cleanup()
	end

	test "some more options" do
		u = %Grub{timeout: 4, cmdline_normal_and_recovery: "quiet", gfxpayload: "640x480", disable_os_prober: true}
		Runner.converge(u, TestingContext.get_context())
		cleanup()
	end
end
