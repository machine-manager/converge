alias Converge.{Unit, Util}

defmodule Converge.EtcCommitted do
	@moduledoc """
	/etc is committed with the latest changes
	"""
	defstruct message: nil
end

defimpl Unit, for: Converge.EtcCommitted do
	def met?(_u, _ctx) do
		maybe_install_prerequisites()
		{out, 0} = System.cmd("git", ["--work-tree=/etc", "--git-dir=/etc/.git", "status", "--short"])
		String.trim_trailing(out) == ""
	end

	def meet(u, _ctx) do
		maybe_install_prerequisites()
		message = case u.message do
			nil -> "converge"
			s   -> s
		end
		# Note: "--" argument after "commit" is not needed or allowed here
		{_, 0} = System.cmd("etckeeper", ["commit", message])
	end

	defp maybe_install_prerequisites() do
		unless File.exists?("/usr/bin/etckeeper") and File.exists?("/usr/bin/git") do
			Util.update_package_index()
		end
		unless File.exists?("/usr/bin/git") do
			Util.install_package("git")
		end
		unless File.exists?("/usr/bin/etckeeper") do
			Util.install_package("etckeeper")
		end
	end
end
