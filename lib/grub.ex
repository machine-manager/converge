alias Gears.StringUtil
alias Converge.{Unit, Runner, AfterMeet, FilePresent}

defmodule Converge.Grub do
	@moduledoc """
	Writes grub configuration to /etc/default/grub and runs `update-grub`.

	Options in `cmdline_normal_and_recovery` are used for both normal and
	recovery boot (i.e. `GRUB_CMDLINE_LINUX`).

	Options in `cmdline_normal_only` are used for only for normal non-recovery
	boot (i.e. `GRUB_CMDLINE_LINUX_DEFAULT`).

	`timeout` is `GRUB_TIMEOUT`.

	`gfxpayload` is `GRUB_GFXPAYLOAD_LINUX`.
	"""
	defstruct timeout: 3, cmdline_normal_and_recovery: "", cmdline_normal_only: "", gfxpayload: nil
end

defimpl Unit, for: Converge.Grub do
	@template ~S"""
	GRUB_DEFAULT=0
	GRUB_TIMEOUT=<%= u.timeout %>
	GRUB_DISTRIBUTOR=`lsb_release -i -s 2> /dev/null || echo Debian`
	GRUB_CMDLINE_LINUX_DEFAULT=<%= inspect(u.cmdline_normal_only) %>
	GRUB_CMDLINE_LINUX=<%= inspect(u.cmdline_normal_and_recovery) %>
	<%= if u.gfxpayload != nil do %>
	GRUB_GFXPAYLOAD_LINUX=<%= u.gfxpayload %>
	<% end %>
	"""

	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		%AfterMeet{
			unit:    %FilePresent{path: "/etc/default/grub", content: make_default_grub(u), mode: 0o644},
			trigger: fn -> {_, 0} = System.cmd("update-grub", [], stderr_to_stdout: true) end
		}
	end

	defp make_default_grub(u) do
		EEx.eval_string(@template, [u: u])
		|> StringUtil.remove_empty_lines
	end

	def package_dependencies(_release), do: ["grub2-common"]
end
