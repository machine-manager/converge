alias Gears.TableFormatter
alias Converge.{Unit, Runner, AfterMeet, FilePresent}

defmodule Converge.Sysfs do
	@moduledoc """
	Writes sysfs variables `variables` to /etc/sysfs.conf and applies them
	using `sysfsutils`.

	`variables` is a Map of string keys to string or integer values.

	Note that removing a variable from `variables` and converging will *not*
	restore the default value until the machine is rebooted!
	"""
	@enforce_keys [:variables]
	defstruct variables: nil
end

defimpl Unit, for: Converge.Sysfs do
	def met?(u, ctx) do
		met_values_in_kernel?(u) and Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	# Are our desired values loaded in the kernel?
	defp met_values_in_kernel?(u) do
		desired_variables_s = stringify_values(u.variables)
		current_variables_s = for {k, _} <- u.variables, into: %{} do
			{k, sysfs_content_to_value(k, File.read!("/sys/#{k}"))}
		end
		current_variables_s == desired_variables_s
	end

	defp stringify_values(variables) do
		variables
		|> Enum.map(fn {k, v} -> {k, to_string(v)} end)
		|> Enum.into(%{})
	end

	defp sysfs_content_to_value("kernel/mm/transparent_hugepage/enabled", value) do
		get_bracketed_word(value)
	end
	defp sysfs_content_to_value("kernel/mm/transparent_hugepage/defrag", value) do
		get_bracketed_word(value)
	end
	defp sysfs_content_to_value(_key, value) do
		value |> String.replace_suffix("\n", "")
	end

	defp get_bracketed_word(s) do
		Regex.run(~r/\[(\w+)\]/, s, capture: :all_but_first) |> hd
	end

	defp make_unit(u) do
		%AfterMeet{
			unit:    %FilePresent{path: "/etc/sysfs.conf", content: variables_to_sysfs(u.variables), mode: 0o644},
			trigger: fn -> {_, 0} = System.cmd("service", ["sysfsutils", "restart"]) end
		}
	end

	# Returns a string containing a sysfs.conf with the variables given
	defp variables_to_sysfs(variables) do
		table = variables
			|> Enum.sort
			|> Enum.map(&variable_to_row/1)
		TableFormatter.format(table, padding: 1) |> IO.iodata_to_binary()
	end

	defp variable_to_row({key, value}) do
		[key, "=", value_to_string(value)]
	end

	defp value_to_string(value) when is_binary(value),  do: value
	defp value_to_string(value) when is_integer(value), do: to_string(value)
end
