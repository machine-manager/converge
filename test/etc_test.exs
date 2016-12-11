alias Converge.{EtcCommitted, Runner}
alias Converge.TestHelpers.TestingContext
alias Gears.FileUtil

defmodule Converge.EtcCommittedTest do
	@moduledoc """
	These tests assume that you have etckeeper installed.
	"""
	use ExUnit.Case, async: true

	test "/etc can be committed with the default message" do
		File.touch!("/etc/converge-etc-test-1")
		e = %EtcCommitted{}
		Runner.converge(e, TestingContext.get_context())
		FileUtil.rm_f!("/etc/converge-etc-test-1")
	end

	test "/etc can be committed with a custom message" do
		File.touch!("/etc/converge-etc-test-2")
		e = %EtcCommitted{message: "custom message from converge"}
		Runner.converge(e, TestingContext.get_context())
		FileUtil.rm_f!("/etc/converge-etc-test-2")
	end
end
