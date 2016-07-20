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

defmodule FileMissing do
	defstruct filename: nil
end

defprotocol Converge do
	@doc "Returns true if the current state is the desired state"
	def met?(p)

	@doc "Changes some state in a way that would satisfy met?"
	def meet(p)
end

defmodule ConvergeError do
	defexception message: "met? returned false after running meet"
end

defmodule Utils do
	def check({:error, term}), do: raise term
	def check(:ok), do: :ok
end

defimpl Converge, for: FilePresent do
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

defmodule Reporter do
	def running(p) do
		IO.puts("#{inspect p}... ")
	end

	def meeting(_) do
		IO.puts("meet... ")
	end

	def already_met(_) do
		IO.puts("OK-already-met")
	end

	def just_met(_) do
		IO.puts("OK-just-met")
	end

	def failed(_) do
		IO.puts("FAILED")
	end

	def done(_) do
		IO.puts("\n")
	end
end

defmodule Idempolicy do
	def converge(p, rep) do
		apply(rep, :running, [p])
		try do
			if Converge.met?(p) do
				apply(rep, :already_met, [p])
			else
				apply(rep, :meeting, [p])
				Converge.meet(p)
				if Converge.met?(p) do
					apply(rep, :just_met, [p])
				else
					apply(rep, :failed, [p])
					raise ConvergeError, message: "Failed to converge: #{inspect p}"
				end
			end
		after
			apply(rep, :done, [p])
		end
	end

	def example() do
		f1 = %FilePresent{filename: "deleteme", content: "Hello world"}
		rep = Reporter
		converge(f1, rep)

		f2 = %FilePresent{filename: "deleteme"}
		p = %PackagesInstalled{names: ["git"]}
		IO.puts(inspect(f1))
		IO.puts(inspect(f2))
		IO.puts(inspect(p))
		IO.puts(inspect [f1, f2, p])
	end
end

defmodule Idempolicy.CLI do
	def main(_ \\ []) do
		Idempolicy.example()
	end
end
