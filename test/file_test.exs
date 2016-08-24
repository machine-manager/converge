import ExUnit.Assertions, only: [assert: 1, assert: 2]

defmodule Converge.FilePresent.FilePresentTest do
	use ExUnit.Case
	alias Converge.{FilePresent, Runner}
	alias Converge.TestHelpers.{SilentReporter}

	test "FilePresent" do
		fp = %FilePresent{filename: "deleteme", content: "multiple\nlines", mode: 0o600}
		Runner.converge(fp, SilentReporter)
	end
end
