defmodule Converge.Mixfile do
	use Mix.Project

	def project do
		[
			app: :converge,
			version: "0.1.1",
			elixir: ">= 1.4.0",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			# Keep this disabled for tests because our tests define some Unit
			# implementations.
			consolidate_protocols: Mix.env == :prod,
			deps: deps(),
		]
	end

	defp deps do
		[
			{:gears, "0.3.0"},
			{:debpress, "0.2.2"}
		]
	end
end
