alias Converge.{DirectoryPresent, FilePresent, SymlinkPresent, FileMissing, Runner}
alias Converge.TestHelpers.{SilentReporter}
alias Gears.FileUtil

defmodule Converge.DirectoryPresentTest do
	use ExUnit.Case, async: true

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "directory with mode 0600" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o600}
		Runner.converge(p, SilentReporter)
	end

	test "directory with mode 0666" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666}
		Runner.converge(p, SilentReporter)
	end

	test "directory with user nobody" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody"}
		Runner.converge(p, SilentReporter)
	end

	test "directory with user nobody and group daemon" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(p, SilentReporter)
	end

	test "immutable directory" do
		d = Path.join(@dir, "immutable")

		p = %DirectoryPresent{path: d, mode: 0o777, immutable: true}
		Runner.converge(p, SilentReporter)
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-1")) end)

		# remove +i attr, make sure we can change the mode, make sure we can
		# touch a file in the now-mutable directory
		p = %DirectoryPresent{path: d, mode: 0o770}
		Runner.converge(p, SilentReporter)
		File.touch!(Path.join(d, "file-2"))

		p = %DirectoryPresent{path: d, mode: 0o776, immutable: true}
		Runner.converge(p, SilentReporter)
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-3")) end)
	end
end

defmodule Converge.FilePresentTest do
	use ExUnit.Case, async: true

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "file with mode 0600" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o600}
		Runner.converge(p, SilentReporter)
	end

	test "file with mode 0666" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666}
		Runner.converge(p, SilentReporter)
	end

	test "file with user nobody" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody"}
		Runner.converge(p, SilentReporter)
	end

	test "file with user nobody and group daemon" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(p, SilentReporter)
	end

	test "file can be changed even if immutable" do
		# setup
		p = %FilePresent{path: @deleteme, content: "content", mode: 0o600, immutable: true}
		Runner.converge(p, SilentReporter)

		# test
		p = %FilePresent{path: @deleteme, content: "changed", mode: 0o600, immutable: true}
		Runner.converge(p, SilentReporter)

		p = %FilePresent{path: @deleteme, content: "changed and mutable", mode: 0o600}
		Runner.converge(p, SilentReporter)
	end
end

defmodule Converge.SymlinkPresentTest do
	use ExUnit.Case, async: true

	@dir FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "symlink" do
		p = %SymlinkPresent{path: @deleteme, dest: "/root/some-dest"}
		Runner.converge(p, SilentReporter)
	end

	test "symlink with user nobody" do
		p = %SymlinkPresent{path: @deleteme, dest: "/root/some-dest", user: "nobody"}
		Runner.converge(p, SilentReporter)
	end

	test "symlink with user nobody and group daemon" do
		p = %SymlinkPresent{path: @deleteme, dest: "/root/some-dest", user: "nobody", group: "daemon"}
		Runner.converge(p, SilentReporter)
	end
end

defmodule Converge.FileMissingTest do
	use ExUnit.Case, async: true

	@dir FileUtil.temp_dir("converge-test")
	@deleteme  Path.join(@dir, "deleteme")
	@immutable Path.join(@dir, "immutable")

	test "works if file doesn't exist" do
		FileUtil.rm_f!(@deleteme)
		m = %FileMissing{path: @deleteme}
		Runner.converge(m, SilentReporter)
	end

	test "works if file exists" do
		m = %FileMissing{path: @deleteme}
		File.touch!(@deleteme)
		Runner.converge(m, SilentReporter)
	end

	test "works if file exists and is immutable" do
		m = %FileMissing{path: @immutable}
		File.touch!(@immutable)
		{"", 0} = System.cmd("chattr", ["+i", "--", @immutable])
		Runner.converge(m, SilentReporter)
	end

	test "does not remove symlink destination when pointing FileMissing at symlink" do
		# setup
		dest = Path.join(@dir, "dest")
		File.touch!(dest)
		p = %SymlinkPresent{path: @deleteme, dest: dest}
		Runner.converge(p, SilentReporter)

		# test
		m = %FileMissing{path: @deleteme}
		Runner.converge(m, SilentReporter)
		assert File.exists?(dest)
	end
end
