defmodule Converge.Fstab do
	@moduledoc """
	Ensures that `/etc/fstab` contains the entries listed in `includes`.

	Note that this will remove any comments from `/etc/fstab`.
	"""

	@enforce_keys [:includes]
	defstruct includes: []
end

defimpl Unit, for: Converge.Fstab do
	alias Converge.FilePresent

	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	def make_unit(u) do
		%FilePresent{path: "/etc/fstab", content: make_fstab(), mode: 0o644}
	end

	def make_fstab(u) do

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

# TODO: implement/find a table formatter
