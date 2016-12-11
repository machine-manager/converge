alias Gears.TableFormatter
alias Converge.{Unit, Runner, FilePresent, FstabEntry}

defmodule Converge.FstabHasEntry do
	@moduledoc """
	Ensures that `/etc/fstab` contains the entry `entry`.  If an existing entry
	with the same `entry.mount_point` exists (note: not `entry.spec`), it will
	be replaced.

	Note that this will also remove any comments from `/etc/fstab`.
	"""

	@enforce_keys [:entry]
	defstruct entry: []
end

defimpl Unit, for: Converge.FstabHasEntry do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		%FilePresent{path: "/etc/fstab", content: make_fstab(u), mode: 0o644}
	end

	# Returns a string containing a new fstab that includes the entry specified in the unit.
	defp make_fstab(u) do
		entries = get_fstab()
			|> Enum.map(fn entry -> {entry.mount_point, entry} end)
			|> Enum.into(%{})
		entries[u.entry.mount_entry] = u.entry
		entries_to_fstab(entries)
	end

	defp get_fstab() do
		File.read!("/etc/fstab")
		|> String.split("\n")
		|> Enum.filter(&line_has_entry?/1)
		|> Enum.map(&line_to_entry/1)
	end

	defp line_has_entry?(line) do
		line != "" and not String.starts_with?(line, "#")
	end

	defp line_to_entry(line) do
		{spec, mount_point, type, options, dump_frequency, fsck_pass_number} = String.split(line, ~r/[ \t]+/)
		dump_frequency   = String.to_integer(dump_frequency)
		fsck_pass_number = String.to_integer(fsck_pass_number)
		%FstabEntry{
			spec:             spec,
			mount_point:      mount_point,
			type:             type,
			options:          options,
			dump_frequency:   dump_frequency,
			fsck_pass_number: fsck_pass_number
		}
	end

	defp entry_to_row(entry) do
		[entry.spec, entry.mount_point, entry.type, entry.options, entry.dump_frequency, entry.fsck_pass_number]
	end

	# Returns a string containing an fstab with entries
	defp entries_to_fstab(entries) do
		table = entries |> Enum.map(&entry_to_row/1)
		TableFormatter.format(table, padding: 2) |> IO.iodata_to_binary()
	end
end

defmodule Converge.FstabEntry do
	@moduledoc """
	spec             - the block special device or remote filesystem to be mounted.
	mount_point      - the mount point for the filesystem.
	type             - the type of filesystem.
	options          - the mount options.
	dump_frequency   - used by dump(8) to determine how frequently to dump the filesystem.
	fsck_pass_number - used by fsck to determine the order in which filesystems are checked at boot time.
	                   The root filesystem should use 1.  Other filesystems should use 2.
	                   Filesystems that can't be fscked should use 0.
	"""
	@enforce_keys [:spec, :mount_point, :type, :options, :fsck_pass_number]
	defstruct spec: nil, mount_point: nil, type: nil, options: nil, dump_frequency: 0, fsck_pass_number: nil
end
