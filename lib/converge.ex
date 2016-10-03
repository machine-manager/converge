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
