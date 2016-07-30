defmodule Converge.Mixfile do
	use Mix.Project

	def project do
		[
			app: :converge,
			version: "0.1.0",
			elixir: "~> 1.4-dev",
			build_embedded: Mix.env == :prod,
			start_permanent: Mix.env == :prod,
			# Keep this disabled for tests because our tests define some Unit
			# implementations.
			consolidate_protocols: Mix.env == :prod,
			escript: escript(),
			deps: deps()
		]
	end

	# Configuration for the OTP application
	# Type "mix help compile.app" for more information
	def application do
		[applications: [:logger, :porcelain]]
	end

	defp deps do
		[{:porcelain, "~> 2.0"}]
	end

	def escript do
		[main_module: Converge.CLI]
	end
end