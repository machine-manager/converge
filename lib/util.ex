defmodule Converge.Util do
	@doc """
	Returns a map with information from /proc/meminfo.  Note that any kB values
	are given as bytes, not as kB.
	"""
	def get_meminfo() do
		# Need cat because File.read! and :file.read_file will return "" because
		# procfs says the file has a size of 0.
		{out, 0} = System.cmd("cat", ["/proc/meminfo"])
		out
		|> String.trim_trailing("\n")
		|> String.split("\n")
		|> Enum.map(fn line ->
			case line |> String.split(~r/\s+/) do
				[label, number, "kB"] ->
					{label |> String.trim_trailing(":"), (number |> String.to_integer) * 1024}
				[label, number] ->
					{label |> String.trim_trailing(":"),  number |> String.to_integer}
			end
		end)
		|> Enum.into(%{})
	end
end
