alias Converge.{Unit, UnitError, All, FileMissing, Runner}

defmodule Converge.SystemdUnitStarted do
	@moduledoc """
	Systemd unit `name` is started.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.SystemdUnitStarted do
	def met?(u, _ctx) do
		# Exit code 0 if active, 3 if inactive or missing
		{_, code} = System.cmd("systemctl", ["status", "--", u.name])
		code == 0
	end

	def meet(u, _ctx) do
		{"", 0} = System.cmd("systemctl", ["start", "--", u.name])
	end
end


defmodule Converge.SystemdUnitStopped do
	@moduledoc """
	Systemd unit `name` is stopped.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.SystemdUnitStopped do
	def met?(u, _ctx) do
		# Exit code 0 if active, 3 if inactive or missing
		{_, code} = System.cmd("systemctl", ["status", "--", u.name])
		code == 3
	end

	def meet(u, _ctx) do
		{"", 0} = System.cmd("systemctl", ["stop", "--", u.name])
	end
end


defmodule Converge.SystemdUnitEnabled do
	@moduledoc """
	Systemd unit `name` is enabled.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.SystemdUnitEnabled do
	def met?(u, _ctx) do
		# Exit code 0 if enabled, 1 if disabled or missing
		{out, code} = System.cmd("systemctl", ["is-enabled", "--", u.name], stderr_to_stdout: true)
		# Instead of just "enabled\n" or "disabled\n", we can also get output like:
		# """
		# chrony.service is not a native service, redirecting to systemd-sysv-install
		# Executing /lib/systemd/systemd-sysv-install is-enabled chrony
		# enabled
		# """
		case {code, out |> get_last_line} do
			{0, "enabled"}  -> true
			{1, "disabled"} -> false
			_               -> raise_error(u, code, out)
		end
	end

	defp raise_error(u, code, out) do
		raise(UnitError,
			"""
			Failed to get enabled/disabled status for #{inspect u.name}; \
			did you run `systemctl daemon-reload` first?
			{exit_code, stdout_and_stderr}: #{inspect {code, out}}
			""")
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("systemctl", ["enable", "--", u.name], stderr_to_stdout: true)
	end

	defp get_last_line(s) do
		s
		|> String.trim
		|> String.split("\n")
		|> List.last
	end
end


defmodule Converge.SystemdUnitDisabled do
	@moduledoc """
	Systemd unit `name` is disabled.
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.SystemdUnitDisabled do
	def met?(u, ctx) do
		not Converge.Unit.Converge.SystemdUnitEnabled.met?(u, ctx)
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("systemctl", ["disable", "--", u.name], stderr_to_stdout: true)
	end
end


defmodule Converge.SystemdUnitsPresent do
	@moduledoc """
	Ensures that the given units (which must have a path starting with
	"/etc/systemd/system") are all met and that any other regular (non-symlink)
	.service files in /etc/systemd/system are not present.

	This is used to ensure that leftover .service files aren't left in
	/etc/systemd/system after roles are removed.

	This does not enable or start any units because it wouldn't know what to do
	with instantiated services (those with an '@' in the filename).
	"""
	@enforce_keys [:units]
	defstruct units: nil
end

defimpl Unit, for: Converge.SystemdUnitsPresent do
	@etc_units "/etc/systemd/system"

	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		keep_basenames = for unit <- u.units do
			if not String.starts_with?(unit.path, @etc_units) do
				raise(RuntimeError, "Unit #{inspect unit} has path that does not start with #{@etc_units}")
			end
			Path.basename(unit.path)
		end
		%All{units: u.units ++ remove_other_service_files_units(keep_basenames)}
	end

	defp remove_other_service_files_units(keep_basenames) do
		current_basenames = get_regular_service_file_basenames() |> MapSet.new
		keep_basenames    = keep_basenames                       |> MapSet.new
		remove_basenames  = MapSet.difference(current_basenames, keep_basenames)
		remove_basenames
		|> Enum.map(fn basename -> %FileMissing{path: Path.join(@etc_units, basename)} end)
	end

	defp get_regular_service_file_basenames() do
		File.ls!(@etc_units)
		|> Enum.filter(fn basename -> String.ends_with?(basename, ".service") end)
		|> Enum.filter(fn basename -> File.regular?(Path.join(@etc_units, basename)) end)
	end
end
