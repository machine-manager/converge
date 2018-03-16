alias Gears.TableFormatter
alias Converge.{Unit, All, UnitError, Runner, FilePresent, SysctlKernelValue}

# Sub-unit used to make it easy to see which sysctl value failed to converge.
defmodule Converge.SysctlKernelValue do
	@moduledoc false
	@enforce_keys [:sysctl_a, :key, :value]
	defstruct sysctl_a: nil, key: nil, value: nil

	def value_to_string(value) when is_binary(value),  do: value
	def value_to_string(value) when is_integer(value), do: to_string(value)
	def value_to_string(value) when is_list(value),    do: Enum.map(value, &value_to_string/1) |> Enum.join("\t")
end

defimpl Unit, for: Converge.SysctlKernelValue do
	import SysctlKernelValue, only: [value_to_string: 1]

	def met?(u, _ctx) do
		u.sysctl_a[u.key] == value_to_string(u.value)
	end

	def meet(_, _ctx) do
		raise(UnitError, "cannot meet; should have been handled by parent unit")
	end

	def package_dependencies(_, _release), do: []
end


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
	import SysctlKernelValue, only: [value_to_string: 1]

	def met?(u, ctx) do
		Runner.met?(%All{units: [file_unit(u)] ++ sysctl_kernel_values(u)}, ctx)
	end

	defp sysctl_kernel_values(u) do
		Enum.map(u.parameters, fn {key, value} ->
			%SysctlKernelValue{sysctl_a: sysctl_a(), key: key, value: value}
		end)
	end

	# Returns a map of all kernel parameters with their current values, as strings
	defp sysctl_a() do
		{out, 0} = System.cmd("sysctl", ["-a"], stderr_to_stdout: true)
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

	def meet(u, ctx) do
		Runner.converge(file_unit(u), ctx)
		# Always run this after converging the FilePresent unit; just because the
		# file was up-to-date does not mean the correct values were in the kernel.
		{_, 0} = System.cmd("service", ["procps", "restart"])
	end

	defp file_unit(u) do
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

	def package_dependencies(_, _release), do: ["procps"]
end
