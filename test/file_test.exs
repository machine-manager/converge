alias Converge.{DirectoryPresent, FilePresent, SymlinkPresent, FileMissing, Runner}
alias Converge.TestHelpers.TestingContext
alias Gears.FileUtil

defmodule Converge.DirectoryPresentTest do
	use ExUnit.Case, async: true

	@dir      FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "directory with mode 0600" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o600}
		Runner.converge(p, TestingContext.get_context())
	end

	test "directory with mode 0666" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666}
		Runner.converge(p, TestingContext.get_context())
	end

	test "directory with user nobody" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "directory with user nobody and group daemon" do
		p = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "immutable directory" do
		d = Path.join(@dir, "immutable")

		p = %DirectoryPresent{path: d, mode: 0o777, immutable: true}
		Runner.converge(p, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-1")) end)

		# remove +i attr, make sure we can change the mode, make sure we can
		# touch a file in the now-mutable directory
		p = %DirectoryPresent{path: d, mode: 0o770}
		Runner.converge(p, TestingContext.get_context())
		File.touch!(Path.join(d, "file-2"))

		p = %DirectoryPresent{path: d, mode: 0o776, immutable: true}
		Runner.converge(p, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-3")) end)
	end
end

defmodule Converge.FilePresentTest do
	use ExUnit.Case, async: true

	@dir      FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "file with mode 0600" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o600}
		Runner.converge(p, TestingContext.get_context())
	end

	test "file with mode 0666" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666}
		Runner.converge(p, TestingContext.get_context())
	end

	test "file with user nobody" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "file with user nobody and group daemon" do
		p = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "file can be changed even if immutable" do
		# setup
		p = %FilePresent{path: @deleteme, content: "content", mode: 0o600, immutable: true}
		Runner.converge(p, TestingContext.get_context())

		# test
		p = %FilePresent{path: @deleteme, content: "changed", mode: 0o600, immutable: true}
		Runner.converge(p, TestingContext.get_context())

		p = %FilePresent{path: @deleteme, content: "changed and mutable", mode: 0o600}
		Runner.converge(p, TestingContext.get_context())
	end

	test "inspect shows content length, not contents; mode in octal" do
		p = %FilePresent{path: "/tmp/not-written", content: "changed", mode: 0o600, immutable: true}
		assert inspect(p) == ~s(%Converge.FilePresent{path: "/tmp/not-written", content: 7 bytes, mode: 0o600, immutable: true, user: "root", group: "root"})
	end
end

defmodule Converge.SymlinkPresentTest do
	use ExUnit.Case, async: true

	@dir       FileUtil.temp_dir("converge-test")
	@deleteme  Path.join(@dir, "deleteme")
	@immutable Path.join(@dir, "immutable")

	test "symlink" do
		p = %SymlinkPresent{path: @deleteme, target: "/root/some-target"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "symlink with user nobody" do
		p = %SymlinkPresent{path: @deleteme, target: "/root/some-target", user: "nobody"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "symlink with user nobody and group daemon" do
		p = %SymlinkPresent{path: @deleteme, target: "/root/some-target", user: "nobody", group: "daemon"}
		Runner.converge(p, TestingContext.get_context())
	end

	test "symlink that replaces an immutable file" do
		# setup
		p = %FilePresent{path: @immutable, content: "content", mode: 0o600, immutable: true}
		Runner.converge(p, TestingContext.get_context())

		# test
		p = %SymlinkPresent{path: @immutable, target: "/root/some-target"}
		Runner.converge(p, TestingContext.get_context())
	end
end

defmodule Converge.FileMissingTest do
	use ExUnit.Case, async: true

	@dir       FileUtil.temp_dir("converge-test")
	@deleteme  Path.join(@dir, "deleteme")
	@immutable Path.join(@dir, "immutable")

	test "works if file doesn't exist" do
		FileUtil.rm_f!(@deleteme)
		m = %FileMissing{path: @deleteme}
		Runner.converge(m, TestingContext.get_context())
	end

	test "works if file exists" do
		m = %FileMissing{path: @deleteme}
		File.touch!(@deleteme)
		Runner.converge(m, TestingContext.get_context())
	end

	test "works if file exists and is immutable" do
		m = %FileMissing{path: @immutable}
		File.touch!(@immutable)
		{"", 0} = System.cmd("chattr", ["+i", "--", @immutable])
		Runner.converge(m, TestingContext.get_context())
	end

	test "does not remove symlink target when pointing FileMissing at symlink" do
		# setup
		target = Path.join(@dir, "target")
		File.touch!(target)
		p = %SymlinkPresent{path: @deleteme, target: target}
		Runner.converge(p, TestingContext.get_context())

		# test
		m = %FileMissing{path: @deleteme}
		Runner.converge(m, TestingContext.get_context())
		assert File.exists?(target)
	end
end
