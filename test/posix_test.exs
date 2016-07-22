import ExUnit.Assertions, only: [assert: 1, assert: 2]

defmodule POSIXTest do
	use ExUnit.Case

	test "FilePresent" do
		fp = %FilePresent{filename: "deleteme", content: "multiple\nlines"}
		Idempolicy.converge(fp, SilentReporter)
	end
end
