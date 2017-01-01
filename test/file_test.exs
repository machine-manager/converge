alias Converge.{DirectoryPresent, FilePresent, SymlinkPresent, FileMissing, DirectoryEmpty, Runner}
alias Converge.TestHelpers.TestingContext
alias Gears.FileUtil

defmodule Converge.DirectoryPresentTest do
	use ExUnit.Case, async: true

	@dir      FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "directory with mode 0600" do
		u = %DirectoryPresent{path: @deleteme, mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with mode 0666" do
		u = %DirectoryPresent{path: @deleteme, mode: 0o666}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with user nobody" do
		u = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with user nobody and group daemon" do
		u = %DirectoryPresent{path: @deleteme, mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "immutable directory" do
		d = Path.join(@dir, "immutable")

		u = %DirectoryPresent{path: d, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-1")) end)

		# remove +i attr, make sure we can change the mode, make sure we can
		# touch a file in the now-mutable directory
		u = %DirectoryPresent{path: d, mode: 0o770}
		Runner.converge(u, TestingContext.get_context())
		File.touch!(Path.join(d, "file-2"))

		u = %DirectoryPresent{path: d, mode: 0o776, immutable: true}
		Runner.converge(u, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(d, "file-3")) end)
	end

	test "immutable directory when mutable directory already exists" do
		d = Path.join(@dir, "immutable")

		# setup
		u = %DirectoryPresent{path: d, mode: 0o666}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %DirectoryPresent{path: d, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
	end

	test "immutable directory when immutable directory already exists but with wrong permissions" do
		d = Path.join(@dir, "immutable")

		# setup
		u = %DirectoryPresent{path: d, mode: 0o666, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %DirectoryPresent{path: d, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.FilePresentTest do
	use ExUnit.Case, async: true

	@dir      FileUtil.temp_dir("converge-test")
	@deleteme Path.join(@dir, "deleteme")

	test "file with mode 0600" do
		u = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with mode 0666" do
		u = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with user nobody" do
		u = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with user nobody and group daemon" do
		u = %FilePresent{path: @deleteme, content: "multiple\nlines", mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file can be changed even if immutable" do
		# setup
		u = %FilePresent{path: @deleteme, content: "content", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %FilePresent{path: @deleteme, content: "changed", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		u = %FilePresent{path: @deleteme, content: "changed and mutable", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file can replace an empty directory" do
		deleteme = FileUtil.temp_dir("converge-test")

		u = %FilePresent{path: deleteme, content: "changed", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "inspect shows content length, not contents; mode in octal" do
		u = %FilePresent{path: "/tmp/not-written", content: "changed", mode: 0o600, immutable: true}
		assert inspect(u) == ~s(%Converge.FilePresent{path: "/tmp/not-written", content: 7 bytes, mode: 0o600, immutable: true, user: "root", group: "root"})
	end
end

defmodule Converge.SymlinkPresentTest do
	use ExUnit.Case, async: true

	@dir       FileUtil.temp_dir("converge-test")
	@deleteme  Path.join(@dir, "deleteme")
	@immutable Path.join(@dir, "immutable")

	test "symlink" do
		u = %SymlinkPresent{path: @deleteme, target: "/root/some-target"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink with user nobody" do
		u = %SymlinkPresent{path: @deleteme, target: "/root/some-target", user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink with user nobody and group daemon" do
		u = %SymlinkPresent{path: @deleteme, target: "/root/some-target", user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink that replaces an immutable file" do
		# setup
		u = %FilePresent{path: @immutable, content: "content", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %SymlinkPresent{path: @immutable, target: "/root/some-target"}
		Runner.converge(u, TestingContext.get_context())
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
		u = %SymlinkPresent{path: @deleteme, target: target}
		Runner.converge(u, TestingContext.get_context())

		# test
		m = %FileMissing{path: @deleteme}
		Runner.converge(m, TestingContext.get_context())
		assert File.exists?(target)
	end
end

defmodule Converge.DirectoryEmptyTest do
	use ExUnit.Case, async: true

	test "raises error if path does not exist" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryEmpty{path: p}
		assert_raise(File.Error, fn -> Runner.converge(u, TestingContext.get_context()) end)
	end

	test "raises error if path is a file" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.touch!(p)
		u = %DirectoryEmpty{path: p}
		assert_raise(File.Error, fn -> Runner.converge(u, TestingContext.get_context()) end)
	end

	test "raises error if child directory is not empty" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		child = Path.join(p, "child")
		File.mkdir!(child)
		File.touch!(Path.join(child, "a-file"))
		u = %DirectoryEmpty{path: p}
		assert_raise(File.Error, fn -> Runner.converge(u, TestingContext.get_context()) end)
	end

	test "deletes regular files and dotfiles and empty directories" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		File.touch!(Path.join(p, "a-file"))
		File.touch!(Path.join(p, ".a-dotfile"))
		File.mkdir!(Path.join(p, "empty-directory"))
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
	end

	test "deletes (immutable) regular files and dotfiles and empty directories" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		File.touch!(Path.join(p, "a-file"))
		File.touch!(Path.join(p, ".a-dotfile"))
		File.mkdir!(Path.join(p, "empty-directory"))
		make_immutable(Path.join(p, "a-file"))
		make_immutable(Path.join(p, ".a-dotfile"))
		make_immutable(Path.join(p, "empty-directory"))
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
	end

	defp make_immutable(p) do
		{"", 0} = System.cmd("chattr", ["+i", "--", p], stderr_to_stdout: true)
	end

	test "deletes symlink, not target" do
		parent = FileUtil.temp_dir("converge-test")
		p      = Path.join(parent, "deleteme")
		File.mkdir!(p)

		# setup
		target = Path.join(parent, "target")
		File.touch!(target)
		u = %SymlinkPresent{path: Path.join(p, "symlink"), target: target}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
		assert File.exists?(target)
	end
end
