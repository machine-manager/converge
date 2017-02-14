alias Converge.{ThingPresent, DirectoryPresent, FilePresent, SymlinkPresent, FileMissing, DirectoryEmpty, Runner}
alias Converge.TestHelpers.TestingContext
alias Gears.FileUtil

defmodule Converge.DirectoryPresentTest do
	use ExUnit.Case, async: true

	test "directory with mode 0600" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryPresent{path: p, mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with mode 0666" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryPresent{path: p, mode: 0o666}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with user nobody" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryPresent{path: p, mode: 0o666, user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with group daemon" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryPresent{path: p, mode: 0o666, group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "directory with user nobody and group daemon" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %DirectoryPresent{path: p, mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "immutable directory" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "immutable")

		u = %DirectoryPresent{path: p, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(p, "file-1")) end)

		# remove +i attr, make sure we can change the mode, make sure we can
		# touch a file in the now-mutable directory
		u = %DirectoryPresent{path: p, mode: 0o770}
		Runner.converge(u, TestingContext.get_context())
		File.touch!(Path.join(p, "file-2"))

		u = %DirectoryPresent{path: p, mode: 0o776, immutable: true}
		Runner.converge(u, TestingContext.get_context())
		assert_raise(File.Error, fn -> File.touch!(Path.join(p, "file-3")) end)
	end

	test "immutable directory when mutable directory already exists" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "immutable")

		# setup
		u = %DirectoryPresent{path: p, mode: 0o666}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %DirectoryPresent{path: p, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
	end

	test "immutable directory when immutable directory already exists but with wrong permissions" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "immutable")

		# setup
		u = %DirectoryPresent{path: p, mode: 0o666, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %DirectoryPresent{path: p, mode: 0o777, immutable: true}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.FilePresentTest do
	use ExUnit.Case, async: true

	test "file with mode 0600" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %FilePresent{path: p, content: "multiple\nlines", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with mode 0666" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %FilePresent{path: p, content: "multiple\nlines", mode: 0o666}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with user nobody" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %FilePresent{path: p, content: "multiple\nlines", mode: 0o666, user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with group daemon" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %FilePresent{path: p, content: "multiple\nlines", mode: 0o666, group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file with user nobody and group daemon" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %FilePresent{path: p, content: "multiple\nlines", mode: 0o666, user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file can be changed even if immutable" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")

		# setup
		u = %FilePresent{path: p, content: "content", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %FilePresent{path: p, content: "changed", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		u = %FilePresent{path: p, content: "changed and mutable", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "file can replace an empty directory" do
		p = FileUtil.temp_dir("converge-test")
		u = %FilePresent{path: p, content: "changed", mode: 0o600}
		Runner.converge(u, TestingContext.get_context())
	end

	test "inspect shows content length, not contents; mode in octal" do
		u = %FilePresent{path: "/tmp/not-written", content: "changed", mode: 0o600, immutable: true}
		assert inspect(u) == ~s(%Converge.FilePresent{path: "/tmp/not-written", content: 7 bytes, mode: 0o600, immutable: true, user: nil, group: nil})
	end
end

defmodule Converge.SymlinkPresentTest do
	use ExUnit.Case, async: true

	test "symlink" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %SymlinkPresent{path: p, target: "/root/some-target"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink with user nobody" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %SymlinkPresent{path: p, target: "/root/some-target", user: "nobody"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink with user nobody and group daemon" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		u = %SymlinkPresent{path: p, target: "/root/some-target", user: "nobody", group: "daemon"}
		Runner.converge(u, TestingContext.get_context())
	end

	test "symlink that replaces an immutable file" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "immutable")

		# setup
		u = %FilePresent{path: p, content: "content", mode: 0o600, immutable: true}
		Runner.converge(u, TestingContext.get_context())

		# test
		u = %SymlinkPresent{path: p, target: "/root/some-target"}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.FileMissingTest do
	use ExUnit.Case, async: true

	test "works if file doesn't exist" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		m = %FileMissing{path: p}
		Runner.converge(m, TestingContext.get_context())
	end

	test "works if file exists" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.touch!(p)
		m = %FileMissing{path: p}
		Runner.converge(m, TestingContext.get_context())
	end

	test "works if file exists and is immutable" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "immutable")
		File.touch!(p)
		{"", 0} = System.cmd("chattr", ["+i", "--", p])
		m = %FileMissing{path: p}
		Runner.converge(m, TestingContext.get_context())
	end

	test "does not remove symlink target when pointing FileMissing at symlink" do
		p = FileUtil.temp_dir("converge-test")

		# setup
		target = Path.join(p, "target")
		File.touch!(target)
		u = %SymlinkPresent{path: Path.join(p, "link"), target: target}
		Runner.converge(u, TestingContext.get_context())

		# test
		m = %FileMissing{path: Path.join(p, "link")}
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

	test "deletes children: regular files and dotfiles and empty directories" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		File.touch!(Path.join(p, "a-file"))
		File.touch!(Path.join(p, ".a-dotfile"))
		File.mkdir!(Path.join(p, "empty-directory"))
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
		assert not ThingPresent.immutable?(p)
	end

	test "deletes immutable children: regular files and dotfiles and empty directories" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		File.touch!(Path.join(p, "a-file"))
		File.touch!(Path.join(p, ".a-dotfile"))
		File.mkdir!(Path.join(p, "empty-directory"))
		ThingPresent.make_immutable(Path.join(p, "a-file"))
		ThingPresent.make_immutable(Path.join(p, ".a-dotfile"))
		ThingPresent.make_immutable(Path.join(p, "empty-directory"))
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
		assert not ThingPresent.immutable?(p)
	end

	test "deletes children: even when given directory is immutable" do
		p = Path.join(FileUtil.temp_dir("converge-test"), "deleteme")
		File.mkdir!(p)
		File.touch!(Path.join(p, "a-file"))
		ThingPresent.make_immutable(p)
		u = %DirectoryEmpty{path: p}
		Runner.converge(u, TestingContext.get_context())
		assert ThingPresent.immutable?(p)
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
