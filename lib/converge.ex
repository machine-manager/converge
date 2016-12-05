defprotocol Converge.Reporter do
	def met?(reporter, unit, ctx)
	def already_met(reporter, unit, ctx)
	def should_meet(reporter, unit, ctx)
	def just_met(reporter, unit, ctx)
	def failed(reporter, unit, ctx)
	def done(reporter, unit, ctx)
end

# TODO: support log_met? == false
defmodule Converge.StandardReporter do
	defstruct pid: nil

	def new(log_met? \\ true, color \\ true) do
		{:ok, pid} = Agent.start_link(fn -> %{
			stack:    [],
			parents:  MapSet.new(),
			log_met?: log_met?,
			color:    color
		} end)
		%Converge.StandardReporter{pid: pid}
	end
end

defimpl Converge.Reporter, for: Converge.StandardReporter do
	defp colorize(r, escape, string) do
		color = Agent.get(r.pid, fn(state) -> state.color end)
		if color do
			[escape, string, :reset]
			|> IO.ANSI.format_fragment(true)
			|> IO.iodata_to_binary
		else
			string
		end
	end

	defp indent(depth) do
		"   " |> String.duplicate(depth)
	end

	def met?(r, u, ctx) do
		stack = Agent.get_and_update(r.pid, fn(state) ->
			{state.stack, %{state | stack: [u | state.stack]}}
		end)
		depth = length(stack)
		need_nl = case depth do
			0 -> false
			_ ->
				Agent.get_and_update(r.pid, fn(state) ->
					parent_unit  = hd(stack)
					# If parent_unit isn't in state.parents yet, we are the first child
					# of that parent and we'll need to print a newline.
					first_child? = state.parents |> MapSet.member?(parent_unit) |> Kernel.not
					new_state    = %{state | parents: state.parents |> MapSet.put(parent_unit)}
					{first_child?, new_state}
				end)
		end
		if need_nl do
			IO.write("\n")
		end
		IO.write("#{indent(depth)}#{inspect u}")
	end

	def already_met(r, u, _ctx) do
		{had_children, depth} = Agent.get(r.pid, fn(state) -> {
			state.parents |> MapSet.member?(u),
			length(state.stack) - 1
		} end)
		case had_children do
			true  -> IO.write("#{indent(depth)}^ ")
			false -> IO.write(" ")
		end
		IO.write(colorize(r, :green, "[met already]"))
	end

	def should_meet(r, _u, _ctx) do
	end

	def just_met(r, u, ctx) do
		{had_children, depth} = Agent.get(r.pid, fn(state) -> {
			state.parents |> MapSet.member?(u),
			length(state.stack) - 1
		} end)
		case had_children do
			true  -> IO.write("#{indent(depth)}^ ")
			false -> IO.write(" ")
		end
		IO.write(colorize(r, [:bright, :black], "[met now]"))
	end

	def failed(r, _u, _ctx) do
	end

	def done(r, u, _ctx) do
		IO.write("\n")
		Agent.update(r.pid, fn(state) ->
			%{state |
				stack:   tl(state.stack),
				parents: state.parents |> MapSet.delete(u)
			}
		end)
	end
end

defmodule Converge.Context do
	@enforce_keys [:reporter, :run_meet]
	defstruct reporter: nil, run_meet: nil
end

defmodule Converge.Runner do
	alias Converge.{Unit, UnitError, Context, Reporter}

	@doc """
	Return `true` if unit `u` is met, otherwise `false`.

	If a unit needs to check if another unit is met, it should call
	`Runner.met?` instead of `Unit.met?`, because `Runner.met?` does the output
	logging that the user expects.
	"""
	@spec met?(Converge.Unit, Converge.Context) :: boolean
	def met?(u, ctx) do
		ctx.reporter |> Reporter.met?(u, ctx)
		met = Unit.met?(u, ctx)
		case met do
			true  -> ctx.reporter |> Reporter.already_met(u, ctx)
			false -> ctx.reporter |> Reporter.should_meet(u, ctx)
		end
		if met or not ctx.run_meet do
			ctx.reporter |> Reporter.done(u, ctx)
		end
		met
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
		if not met?(u, ctx) and ctx.run_meet do
			Unit.meet(u, ctx)
			# Call Unit.met? instead of Runner.met? to avoid calling
			# Reporter.met? a second time
			if Unit.met?(u, ctx) do
				ctx.reporter |> Reporter.just_met(u, ctx)
			else
				ctx.reporter |> Reporter.failed(u, ctx)
				raise UnitError, message: "Failed to converge: #{inspect u}"
			end
			ctx.reporter |> Reporter.done(u, ctx)
		end
		nil
	end
end
