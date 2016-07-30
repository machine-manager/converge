# Things to implement:
# File with content + user owner + group owner + permissions
# Package installed
# Package uninstalled
# User exists
# File-matches-regexp + edit operation to fix it
# File/directory exists, else run command to fix it
# Git URL cloned and checked out to a specific revision

defmodule PackagesInstalled do
	defstruct names: nil
end


defmodule PackagesMissing do
	defstruct names: nil
end


defmodule UserExists do
	defstruct name: nil
end


defmodule FilePresent do
	defstruct filename: nil, content: nil
end

defimpl Unit, for: FilePresent do
	def met?(p) do
		case File.open(p.filename, [:read]) do
			# TODO: guard against giant files
			{:ok, file} -> case IO.binread(file, :all) do
				{:error, _} -> false
				existing -> p.content == existing
			end
			{:error, _} -> false
		end
	end

	def meet(p) do
		f = File.open!(p.filename, [:write])
		try do
			Utils.check(IO.binwrite(f, p.content))
		after
			File.close(f)
		end
	end
end


defmodule FileMissing do
	defstruct filename: nil
end
