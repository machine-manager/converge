alias Converge.Unit

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
