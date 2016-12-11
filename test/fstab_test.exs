alias Gears.FileUtil
alias Converge.{Fstab, FstabEntry, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.FstabTest do
	use ExUnit.Case, async: true

	@dir FileUtil.temp_dir("converge-fstab-test")

	test "get_entries works on an empty fstab file" do
		p = Path.join(@dir, "empty-fstab")
		File.write!(p, "")
		assert Fstab.get_entries(fstab_file: p) == []
	end

	test "get_entries works on an fstab file with mixed separators" do
		p = Path.join(@dir, "empty-fstab")
		File.write!(p, 
			"""
			/dev/mapper/rootdrive                     /         xfs  defaults  \t 0 2
			proc                                      /proc     proc hidepid=2    0 0
			""")
		assert Fstab.get_entries(fstab_file: p) == [
			%FstabEntry{spec: "/dev/mapper/rootdrive", mount_point: "/",     type: "xfs",  options: "defaults",  dump_frequency: 0, fsck_pass_number: 2},
			%FstabEntry{spec: "proc",                  mount_point: "/proc", type: "proc", options: "hidepid=2", dump_frequency: 0, fsck_pass_number: 0},
		]
	end

	test "get_entries works on an fstab file with mixed separators, comments, and empty lines" do
		p = Path.join(@dir, "empty-fstab")
		File.write!(p, 
			"""
			# Blah blah blah
			/dev/mapper/rootdrive                     /         xfs  defaults  \t 0 2

			# Make /proc secure
			proc                                      /proc     proc hidepid=2    0 0

			""")
		assert Fstab.get_entries(fstab_file: p) == [
			%FstabEntry{spec: "/dev/mapper/rootdrive", mount_point: "/",     type: "xfs",  options: "defaults",  dump_frequency: 0, fsck_pass_number: 2},
			%FstabEntry{spec: "proc",                  mount_point: "/proc", type: "proc", options: "hidepid=2", dump_frequency: 0, fsck_pass_number: 0},
		]
	end
end
