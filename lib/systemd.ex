alias Converge.{Unit, UnitError}

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
			_               -> raise UnitError, message: """
			                                             Failed to get enabled/disabled status for #{inspect u.name}; \
			                                             did you run `systemctl daemon-reload` first?
			                                             {exit_code, stdout_and_stderr}: #{inspect {code, out}}
			                                             """
		end
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
