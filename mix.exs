defmodule Idempolicy.Mixfile do
	use Mix.Project

	def project do
		[app: :idempolicy,
		 version: "0.1.0",
		 elixir: "~> 1.4-dev",
		 build_embedded: Mix.env == :prod,
		 start_permanent: Mix.env == :prod,
		 escript: escript(),
		 deps: deps()]
	end

	# Configuration for the OTP application
	# Type "mix help compile.app" for more information
	def application do
		[applications: [:logger]]
	end

	defp deps do
		[{:exrm, "~> 1.0.6"}]
	end

	def escript do
		[main_module: Idempolicy.CLI]
	end
end
