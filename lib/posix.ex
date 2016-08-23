# Things to implement:
# File with content + user owner + group owner + permissions
# Package installed
# Package uninstalled
# User exists
# File-matches-regexp + edit operation to fix it
# File/directory exists, else run command to fix it
# Git URL cloned and checked out to a specific revision

import Record, only: [defrecordp: 2, extract: 2]

defmodule PackagesInstalled do
	@enforce_keys [:names]
	defstruct names: nil
end


defmodule PackagesMissing do
	@enforce_keys [:names]
	defstruct names: nil
end


defmodule UserExists do
	@enforce_keys [:name]
	defstruct name: nil
end


defmodule FilePresent do
	@enforce_keys [:filename, :content, :mode]
	defstruct filename: nil, content: nil, mode: nil
end

defimpl Unit, for: FilePresent do
	use Bitwise
	defrecordp :file_info, extract(:file_info, from_lib: "kernel/include/file.hrl")

	defp met_contents?(p) do
		case File.open(p.filename, [:read]) do
			# TODO: guard against giant files
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing -> p.content == existing
			end
			{:error, _} -> false
		end
	end

	defp mode_without_type(mode) do
		mode &&& 0o7777
	end

	defp met_mode?(p) do
		case :file.read_file_info(p.filename) do
			{:ok, file_info(mode: mode)} ->
				mode_without_type(mode) == p.mode
			_ -> false
		end
	end

	def met?(p) do
		met_mode?(p) and met_contents?(p)
	end

	def meet(p) do
		f = File.open!(p.filename, [:write])
		# Must chmod before writing possibly-secret content
		File.chmod!(p.filename, p.mode)
		try do
			Utils.check(IO.binwrite(f, p.content))
		after
			File.close(f)
		end
	end
end


defmodule FileMissing do
	@enforce_keys [:filename]
	defstruct filename: nil
end
