alias Gears.TableFormatter
alias Converge.{Unit, Runner, FilePresent}

defmodule Converge.Sysctl do
	@moduledoc """
	Writes kernel parameters `parameters` to /etc/sysctl.conf and applies them.

	`parameter` is a Map of string keys to string or integer values.

	Note that removing a parameter from `parameters` and converging will *not*
	restore the default value until the machine is rebooted!
	"""
	@enforce_keys [:parameters]
	defstruct parameters: nil
end

defimpl Unit, for: Converge.Sysctl do
	def met?(u, ctx) do
		met_values_in_kernel?(u) and Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
		# Always set values after converging the FilePresent unit; just because the
		# file was up-to-date does not mean the correct values were in the kernel.
		#
		# Just do what /etc/init.d/procps does because `systemctl restart procps`
		# doesn't always wait long enough for the values to be loaded before we
		# check them.
		{_, 0} = System.cmd("/sbin/sysctl", ["-q", "--system"])
	end

	# Are our desired values loaded in the kernel?
	defp met_values_in_kernel?(u) do
		desired_parameters_s = stringify_values(u.parameters)
		current_parameters_s = sysctl_a() |> Map.take(desired_parameters_s |> Map.keys)
		current_parameters_s == desired_parameters_s
	end

	defp stringify_values(parameters) do
		parameters
		|> Enum.map(fn {k, v} -> {k, value_to_string(v)} end)
		|> Enum.into(%{})
	end

	# Returns a map of all kernel parameters with their current values, as strings
	defp sysctl_a() do
		{out, 0} = System.cmd("/sbin/sysctl", ["-a"], stderr_to_stdout: true)
		out
		|> String.replace_suffix("\n", "")
		|> String.split("\n")
		# Skip over error lines like:
		# sysctl: reading key "net.ipv6.conf.enp0s3.stable_secret"
		|> Enum.filter(fn line -> line =~ " = " end)
		|> Enum.map(fn line ->
			[k, v] = String.split(line, " = ", parts: 2)
			{k, v}
		end)
		|> Enum.into(%{})
	end

	defp make_unit(u) do
		%FilePresent{path: "/etc/sysctl.conf", content: parameters_to_sysctl(u.parameters), mode: 0o644}
	end

	# Returns a string containing a sysctl.conf with the parameters given
	defp parameters_to_sysctl(parameters) do
		table = parameters
			|> Enum.sort
			|> Enum.map(&parameter_to_row/1)
		TableFormatter.format(table, padding: 1) |> IO.iodata_to_binary()
	end

	defp parameter_to_row({key, value}) do
		[key, "=", value_to_string(value)]
	end

	defp value_to_string(value) when is_binary(value),  do: value
	defp value_to_string(value) when is_integer(value), do: to_string(value)
	defp value_to_string(value) when is_list(value),    do: Enum.map(value, &value_to_string/1) |> Enum.join("\t")

	def package_dependencies(_, _release), do: ["procps"]
end
