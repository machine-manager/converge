defmodule Converge.Reporter do
	def running(u) do
		IO.write("#{inspect u}... ")
	end

	def already_met(_) do
		IO.write("already met")
	end

	# Used when ctx.run_meet == false
	def not_met(_) do
		IO.write("not met")
	end

	def meeting(_) do
		IO.write("meet()... ")
	end

	def just_met(_) do
		IO.write("just met")
	end

	def failed(_) do
		IO.write("FAILED")
	end

	def done(_) do
		IO.write("\n")
	end
end

defmodule Converge.Context do
	@enforce_keys [:reporter, :run_meet]
	defstruct reporter: nil, run_meet: nil
end

defmodule Converge.Runner do
	alias Converge.{Unit, UnitError}

	@doc """
	Converge unit `u`: run `met?` to check if state needs to be modified, and
	it it does, run `meet`, then `met?` again to ensure that `meet` worked
	correctly.  If `met?` returns `false` the second time, raise `UnitError`.

	If `ctx.run_meet == false`, never run `meet` on units.

	Everything is logged to `ctx.reporter`.
	"""
	@spec converge(Converge.Unit, Converge.Context) :: nil
	def converge(u, ctx) do
		apply(ctx.reporter, :running, [u])
		try do
			if Unit.met?(u) do
				apply(ctx.reporter, :already_met, [u])
			else
				if not ctx.run_meet do
					apply(ctx.reporter, :not_met, [u])
				else
					apply(ctx.reporter, :meeting, [u])
					Unit.meet(u, ctx)
					if Unit.met?(u) do
						apply(ctx.reporter, :just_met, [u])
					else
						apply(ctx.reporter, :failed, [u])
						raise UnitError, message: "Failed to converge: #{inspect u}"
					end
				end
			end
		after
			apply(ctx.reporter, :done, [u])
		end
		nil
	end
end
