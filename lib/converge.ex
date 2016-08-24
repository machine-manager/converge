defmodule Converge.Reporter do
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

defmodule Converge.Runner do
	alias Converge.{Unit, UnitError}

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
end

defmodule Converge.CLI do
	def main(_ \\ []) do
		# TODO: move this example

		alias Converge.{FilePresent, PackagesInstalled, Reporter, Runner}

		f1 = %FilePresent{filename: "deleteme", content: "Hello world", mode: 0o600}
		rep = Reporter
		Runner.converge(f1, rep)

		f2 = %FilePresent{filename: "deleteme", content: "Stuff", mode: 0o600}
		p = %PackagesInstalled{names: ["git"]}
		IO.puts(inspect(f1))
		IO.puts(inspect(f2))
		IO.puts(inspect(p))
		IO.puts(inspect [f1, f2, p])
	end
end
