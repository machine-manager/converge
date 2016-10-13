defmodule Converge.Mixfile do
	use Mix.Project

	def project do
		[
			app: :converge,
			version: "0.1.0",
			elixir: ">= 1.3.2",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			# Keep this disabled for tests because our tests define some Unit
			# implementations.
			consolidate_protocols: Mix.env == :prod,
			deps: deps(),
		]
	end

	# Configuration for the OTP application
	# Type "mix help compile.app" for more information
	def application do
		[applications: [:logger, :debpress]]
	end

	defp deps do
		[
			{:gears, "0.1.0"},
			{:debpress, "0.2.1"}
		]
	end
end
