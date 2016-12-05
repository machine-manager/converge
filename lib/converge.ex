defmodule Converge.ReporterOptions do
	defstruct log_met?: true, color: true
end

# TODO: support log_met?: false
# TODO: support color: false
# TODO: print \n[^ met now] / \n[^ met already] when `depth` is unit is less than last unit
defmodule Converge.StandardReporter do
	defp colorize(escape, string, %{color: color}) do
		if color do
			[escape, string, :reset]
			|> IO.ANSI.format_fragment(true)
			|> IO.iodata_to_binary
		else
			string
		end
	end

	def met?(u, ctx) do
		indent = "   " |> String.duplicate(ctx.depth)
		IO.write(colorize(:green, "#{indent}#{inspect u}\n", ctx.reporter_options))
	end

	def already_met(_, _) do
		IO.write("[met already]")
	end

	def should_meet(_, _) do

	end

	def just_met(_, ctx) do
		IO.write(colorize([:bright, :black], "[met now]", ctx.reporter_options))
	end

	def failed(_, _) do

	end

	def done(_, _) do

	end
end

defmodule Converge.Context do
	@enforce_keys [:reporter, :run_meet]
	defstruct reporter: nil, reporter_options: %Converge.ReporterOptions{}, run_meet: nil, depth: -1
end

defmodule Converge.Runner do
	alias Converge.{Unit, UnitError, Context}

	@doc """
	Return `true` if unit `u` is met, otherwise `false`.

	If a unit needs to check if another unit is met, it should call
	`Runner.met?` instead of `Unit.met?`, because `Runner.met?` does the output
	logging that the user expects.
	"""
	@spec met?(Converge.Unit, Converge.Context) :: boolean
	def met?(u, ctx) do
		ctx = %Context{ctx | depth: ctx.depth + 1}
		apply(ctx.reporter, :met?, [u, ctx])
		Unit.met?(u, ctx)
	end

	@doc """
	Converge unit `u`: run `met?` to check if state needs to be modified, and
	it it does, run `meet`, then `met?` again to ensure that `meet` worked
	correctly.  If `met?` returns `false` the second time, raise `UnitError`.

	If `ctx.run_meet == false`, never run `meet` on units.

	Everything is logged to `ctx.reporter`.
	"""
	@spec converge(Converge.Unit, Converge.Context) :: nil
	def converge(u, ctx) do
		ctx_orig = ctx
		ctx      = %Context{ctx | depth: ctx.depth + 1}
		try do
			if met?(u, ctx_orig) do
				apply(ctx.reporter, :already_met, [u, ctx])
			else
				apply(ctx.reporter, :should_meet, [u, ctx])
				if ctx.run_meet do
					Unit.meet(u, ctx)
					if met?(u, ctx_orig) do
						apply(ctx.reporter, :just_met, [u, ctx])
					else
						apply(ctx.reporter, :failed, [u, ctx])
						raise UnitError, message: "Failed to converge: #{inspect u}"
					end
				end
			end
		after
			apply(ctx.reporter, :done, [u, ctx])
		end
		nil
	end
end
