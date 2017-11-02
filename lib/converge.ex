defprotocol Converge.Reporter do
	def open(reporter, unit, which)
	def close(reporter, unit, result)
end

# TODO: support log_met? == false
defmodule Converge.TerminalReporter do
	@enforce_keys [:pid, :log_met?, :color]
	defstruct pid: nil, log_met?: nil, color: nil

	def new(log_met? \\ true, color \\ true) do
		{:ok, pid} = Agent.start_link(fn -> %{
			stack:    [],
			parents:  MapSet.new()
		} end)
		%Converge.TerminalReporter{pid: pid, log_met?: log_met?, color: color}
	end
end

defimpl Converge.Reporter, for: Converge.TerminalReporter do
	def open(r, u, which) do
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
					first_child? = not MapSet.member?(state.parents, parent_unit)
					new_state    = %{state | parents: MapSet.put(state.parents, parent_unit)}
					{first_child?, new_state}
				end)
		end
		if need_nl do
			IO.write("\n")
		end
		color = case which do
			:met? -> :yellow
			:meet -> [:yellow, :inverse]
		end
		IO.write(
			"""
			#{colorize(r, color, Atom.to_string(which))} \
			#{indent(depth)}\
			#{inspect u, safe: false, syntax_colors: syntax_colors()}\
			""")
	end

	def close(r, u, result) do
		{had_children, depth} = Agent.get(r.pid, fn(state) -> {
			MapSet.member?(state.parents, u),
			length(state.stack) - 1
		} end)
		case had_children do
			true  -> IO.write("     #{indent(depth)}")
			false -> IO.write(" ")
		end
		{message, color} = case result do
			:unmet    -> {"[unmet]",    [:inverse, :red]}
			:ran_meet -> {"[ran meet]", [:inverse, :magenta]}
			:met      -> {"[met]",      [:inverse, :green]}
		end
		IO.write(colorize(r, color, message))
		IO.write("\n")
		Agent.update(r.pid, fn(state) ->
			%{state |
				stack:   tl(state.stack),
				parents: MapSet.delete(state.parents, u)
			}
		end)
	end

	defp indent(depth) do
		String.duplicate("|  ", depth)
	end

	defp colorize(r, escape, string) do
		if r.color do
			[escape, string, :reset]
			|> IO.ANSI.format_fragment(true)
			|> IO.iodata_to_binary
		else
			string
		end
	end

	defp syntax_colors() do
		[
			map:     :bright,
			atom:    :yellow,
			string:  :cyan,
			number:  :red,
			list:    :default_color,
			boolean: :magenta,
			nil:     :magenta,
			tuple:   :default_color,
			binary:  :default_color
		]
	end
end


defmodule Converge.SilentReporter do
	defstruct []
	def new() do
		%Converge.SilentReporter{}
	end
end

defimpl Converge.Reporter, for: Converge.SilentReporter do
	def open(_reporter, unit, _which) do
		# Exercise inspect() but don't actually print
		_ = inspect(unit)
	end
	def close(_reporter, unit, _result) do
		_ = inspect(unit)
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
	@spec met?(Unit, Context) :: boolean
	def met?(u, ctx) do
		Reporter.open(ctx.reporter, u, :met?)
		met = Unit.met?(u, ctx)
		result = case met do
			true  -> :met
			false -> :unmet
		end
		Reporter.close(ctx.reporter, u, result)
		met
	end

	@doc """
	Converge unit `u`: run `met?` to check if state needs to be modified, and
	it it does, run `meet`, then `met?` again to ensure that `meet` worked
	correctly.  If `met?` returns `false` the second time, raise `UnitError`.

	If `override_met? == true`, run `meet` on `u` without checking `met?` on
	`u` first.  Do not use this except to modify unit behavior in rare cases.

	If `ctx.run_meet == false`, never run `meet` on any units.

	Everything is logged to `ctx.reporter`.
	"""
	@spec converge(Unit, Context) :: nil
	def converge(u, ctx, override_met? \\ false) do
		if (override_met? or not met?(u, ctx)) and ctx.run_meet do
			Reporter.open(ctx.reporter, u, :meet)
			Unit.meet(u, ctx)
			Reporter.close(ctx.reporter, u, :ran_meet)
			if not met?(u, ctx) do
				raise(UnitError, "Failed to converge: #{inspect u}")
			end
		end
		nil
	end
end
