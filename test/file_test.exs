alias Converge.{DirectoryPresent, FilePresent, FileMissing, Runner}
alias Converge.TestHelpers.{SilentReporter}
alias Gears.FileUtil

defmodule Converge.DirectoryPresentTest do
	use ExUnit.Case

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "directory with mode 0600" do
		fp = %DirectoryPresent{path: @deleteme, mode: 0o600}
		Runner.converge(fp, SilentReporter)
	end

	test "directory with mode 0666" do
		fp = %DirectoryPresent{path: @deleteme, mode: 0o666}
		Runner.converge(fp, SilentReporter)
	end

	test "directory with user nobody" do
		fp = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody"}
		Runner.converge(fp, SilentReporter)
	end

	test "directory with user nobody and group daemon" do
		fp = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(fp, SilentReporter)
	end
end

defmodule Converge.FilePresentTest do
	use ExUnit.Case

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "file with mode 0600" do
		fp = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o600}
		Runner.converge(fp, SilentReporter)
	end

	test "file with mode 0666" do
		fp = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666}
		Runner.converge(fp, SilentReporter)
	end

	test "file with user nobody" do
		fp = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody"}
		Runner.converge(fp, SilentReporter)
	end

	test "file with user nobody and group daemon" do
		fp = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(fp, SilentReporter)
	end
end

defmodule Converge.FileMissingTest do
	use ExUnit.Case

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "works if file doesn't exist" do
		FileUtil.rm_f!(@deleteme)
		fm = %FileMissing{path: @deleteme}
		Runner.converge(fm, SilentReporter)
	end

	test "works if file exists" do
		fm = %FileMissing{path: @deleteme}
		File.touch!(@deleteme)
		Runner.converge(fm, SilentReporter)
	end
end
