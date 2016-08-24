import ExUnit.Assertions, only: [assert: 1, assert: 2]

alias Converge.{FilePresent, FileMissing, Runner}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.FilePresentTest do
	use ExUnit.Case

	test "FilePresent" do
		fp = %FilePresent{filename: "deleteme", content: "multiple\nlines", mode: 0o600}
		Runner.converge(fp, SilentReporter)
	end
end

defmodule Converge.FileMissingTest do
	use ExUnit.Case

	test "FileMissing" do
		fm = %FileMissing{filename: "deleteme"}
		Runner.converge(fm, SilentReporter)
		File.touch!("deleteme")
		Runner.converge(fm, SilentReporter)
	end
end
