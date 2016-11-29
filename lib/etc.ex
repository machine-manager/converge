alias Converge.Unit

defmodule Converge.EtcCommitted do
	@moduledoc """
	/etc is committed with the latest changes
	"""
	defstruct message: nil
end

defimpl Unit, for: Converge.EtcCommitted do
	def met?(u) do
		{out, 0} = System.cmd("git", ["--work-tree=/etc", "--git-dir=/etc/.git", "status", "--short"])
		String.trim_trailing(out) == ""
	end

	def meet(u, _) do
		message = case u.message do
			nil -> "converge"
			s   -> s
		end
		# Note: "--" argument after "commit" is not needed or allowed here
		{_, 0} = System.cmd("etckeeper", ["commit", message])
	end
end
