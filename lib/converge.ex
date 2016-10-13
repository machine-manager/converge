defmodule Converge.Reporter do
	def running(u) do
		IO.write("#{inspect u}... ")
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

	def converge(u, rep) do
		apply(rep, :running, [u])
		try do
			if Unit.met?(u) do
				apply(rep, :already_met, [u])
			else
				apply(rep, :meeting, [u])
				Unit.meet(u, rep)
				if Unit.met?(u) do
					apply(rep, :just_met, [u])
				else
					apply(rep, :failed, [u])
					raise UnitError, message: "Failed to converge: #{inspect u}"
				end
			end
		after
			apply(rep, :done, [u])
		end
	end
end
