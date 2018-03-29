alias Gears.FileUtil
alias Converge.{Unit, UnitError, All, FileMissing, AfterMeet, Runner}

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
		{_, code} = System.cmd("systemctl", ["status", "--", u.name], stderr_to_stdout: true)
		code == 0
	end

	def meet(u, _ctx) do
		case System.cmd("systemctl", ["start", "--", u.name], stderr_to_stdout: true) do
			{"", 0}          -> nil
			{out, exit_code} ->
				raise(UnitError,
					"""
					Failed to start #{u.name}: `systemctl start` returned exit code
					#{exit_code}, output #{inspect out}
					""")
		end
	end

	def package_dependencies(_, _release), do: ["systemd"]
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
		{_, code} = System.cmd("systemctl", ["status", "--", u.name], stderr_to_stdout: true)
		code == 3
	end

	def meet(u, _ctx) do
		case System.cmd("systemctl", ["stop", "--", u.name], stderr_to_stdout: true) do
			{"", 0}          -> nil
			{out, exit_code} ->
				raise(UnitError,
					"""
					Failed to stop #{u.name}: `systemctl stop` returned exit code
					#{exit_code}, output #{inspect out}
					""")
		end
	end

	def package_dependencies(_, _release), do: ["systemd"]
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
		case {code, get_last_line(out)} do
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

	def package_dependencies(_, _release), do: ["systemd"]
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

	def package_dependencies(_, _release), do: ["systemd"]
end


defmodule Converge.EtcSystemdUnitFiles do
	@moduledoc """
	Ensures that the given converge units (which must have a path starting with
	"/etc/systemd/system") are all met and that any other regular (non-symlink)
	.service files in /etc/systemd/system not created by those converge units
	are *not* present.  If any files were added/changed/removed, this then runs
	`systemctl daemon-reload`.

	This is used to ensure that leftover .service files are not left around in
	/etc/systemd/system.

	This does not enable or start any units because it wouldn't know what to do
	with instantiated services (those with an '@' in the filename).
	"""
	@enforce_keys [:units]
	defstruct units: nil
end

defimpl Unit, for: Converge.EtcSystemdUnitFiles do
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
		%AfterMeet{
			unit:    %All{units: u.units ++ remove_other_service_files_units(keep_basenames)},
			trigger: fn -> {_, 0} = System.cmd("systemctl", ["daemon-reload"]) end,
		}
	end

	defp remove_other_service_files_units(keep_basenames) do
		keep_basenames    = MapSet.new(keep_basenames)
		current_basenames = MapSet.new(get_regular_service_file_basenames())
		remove_basenames  = MapSet.difference(current_basenames, keep_basenames)
		for basename <- remove_basenames do
			%FileMissing{path: Path.join(@etc_units, basename)}
		end
	end

	defp get_regular_service_file_basenames() do
		File.ls!(@etc_units)
		|> Enum.filter(fn basename ->
				path = Path.join(@etc_units, basename)
				String.ends_with?(path, ".service") and \
					not FileUtil.symlink?(path) and File.regular?(path)
			end)
	end

	def package_dependencies(_, _release), do: ["systemd"]
end
