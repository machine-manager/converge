defprotocol Unit do
	@doc "Returns true if the current state is the desired state"
	def met?(p)

	@doc "Changes some state in a way that would satisfy met?"
	def meet(p)
end

defmodule UnitError do
	defexception message: "met? returned false after running meet"
end

defmodule Utils do
	def check({:error, term}), do: raise term
	def check(:ok), do: :ok
end

defmodule Reporter do
	def running(p) do
		IO.write("#{inspect p}... ")
	end

	def meeting(_) do
		IO.write("meet()... ")
	end

	def already_met(_) do
		IO.write("OK-already-met")
	end

	def just_met(_) do
		IO.write("OK-just-met")
	end

	def failed(_) do
		IO.write("FAILED")
	end

	def done(_) do
		IO.write("\n")
	end
end

defmodule Converge do
	def converge(p, rep) do
		apply(rep, :running, [p])
		try do
			if Unit.met?(p) do
				apply(rep, :already_met, [p])
			else
				apply(rep, :meeting, [p])
				Unit.meet(p)
				if Unit.met?(p) do
					apply(rep, :just_met, [p])
				else
					apply(rep, :failed, [p])
					raise UnitError, message: "Failed to converge: #{inspect p}"
				end
			end
		after
			apply(rep, :done, [p])
		end
	end

	def example() do
		f1 = %FilePresent{filename: "deleteme", content: "Hello world", mode: 0o600}
		rep = Reporter
		converge(f1, rep)

		f2 = %FilePresent{filename: "deleteme", content: "Stuff", mode: 0o600}
		p = %PackagesInstalled{names: ["git"]}
		IO.puts(inspect(f1))
		IO.puts(inspect(f2))
		IO.puts(inspect(p))
		IO.puts(inspect [f1, f2, p])
	end
end

defmodule Converge.CLI do
	def main(_ \\ []) do
		Converge.example()
	end
end
