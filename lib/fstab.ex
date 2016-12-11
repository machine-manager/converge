alias Gears.TableFormatter
alias Converge.{Unit, Runner, FilePresent, FstabEntry}

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

defmodule Converge.Fstab do
	@moduledoc """
	Make sure `/etc/fstab` consists of just entries `entries`.

	If you want to keep some existing entries, use `Fstab.get_entries()` to
	retrieve them.  You can then index them on `mount_point` with:

	```
	Fstab.get_entries()
		|> Enum.map(fn entry -> {entry.mount_point, entry} end)
		|> Enum.into(%{})
	```
	"""

	@enforce_keys [:entries]
	defstruct entries: [], fstab_file: "/etc/fstab"

	@doc """
	Returns a list of existing entries in `/etc/fstab` (or another `fstab_file`)
	"""
	def get_entries(options \\ []) do
		fstab_file = Keyword.get(options, :fstab_file, "/etc/fstab")
		File.read!(fstab_file)
		|> String.split("\n")
		|> Enum.filter(&line_has_entry?/1)
		|> Enum.map(&line_to_entry/1)
	end

	defp line_has_entry?(line) do
		line != "" and not String.starts_with?(line, "#")
	end

	defp line_to_entry(line) do
		[spec, mount_point, type, options, dump_frequency, fsck_pass_number] = String.split(line, ~r/[ \t]+/)
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
end

defimpl Unit, for: Converge.Fstab do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		%FilePresent{path: u.fstab_file, content: entries_to_fstab(u.entries), mode: 0o644}
	end

	defp entry_to_row(entry) do
		# fstab calls these:
		# fs_spec,   fs_file,           fs_vfstype, fs_mntops,     fs_freq,              fs_passno
		[entry.spec, entry.mount_point, entry.type, entry.options, entry.dump_frequency, entry.fsck_pass_number]
	end

	# Returns a string containing an fstab with the entries given
	defp entries_to_fstab(entries) do
		table = entries |> Enum.map(&entry_to_row/1)
		TableFormatter.format(table, padding: 2) |> IO.iodata_to_binary()
	end
end
