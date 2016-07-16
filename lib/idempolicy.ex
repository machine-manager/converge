# Things to implement:
# File with contents + user owner + group owner + permissions
# Package installed
# Package uninstalled
# User exists
# File-matches-regexp + edit operation to fix it
# File/directory exists, else run command to fix it
# Git URL cloned and checked out to a specific revision

defmodule PackageInstalled do
	defstruct name: nil
end

defmodule PackageMissing do
	defstruct name: nil
end

defmodule UserExists do
	defstruct name: nil
end

defmodule FilePresent do
	defstruct filename: nil, contents: nil
end

defmodule FileMissing do
	defstruct filename: nil
end

defprotocol Converge do
	@doc "Returns true if the current state is the desired state"
	def met?(_)

	@doc "Changes some state in a way that would satisfy met?"
	def meet(_)
end

defimpl Converge, for: FilePresent do
	def met?(f) do
		case File.open(f.filename, [:read]) do
			{:ok, file} -> true
			{:error, reason} -> false
		end
	end

	def meet(f) do
		File.touch(f.filename)
	end
end

defmodule Idempolicy do
	def converge(p) do
		IO.puts(inspect(p))
		if not Converge.met?(p) do
			IO.puts("Not met, calling meet()...")
			Converge.meet(p)
		else
			IO.puts("Already met")
		end
	end

	def example() do
		f1 = %FilePresent{filename: "deleteme", contents: "Hello world"}
		converge(f1)

		f2 = %FilePresent{filename: "deleteme"}
		p = %PackageInstalled{name: "git"}
		IO.puts(inspect(f1))
		IO.puts(inspect(f2))
		IO.puts(inspect(p))
		IO.puts(inspect [f1, f2, p])
	end
end

Idempolicy.example()
