alias Converge.{PackagesInstalled, Runner}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.PackagesInstalledTest do
	use ExUnit.Case

	test "packages are installed and removed as needed" do
		p = %PackagesInstalled{depends: ["fortune", "fortunes-eo"]}
		Runner.converge(p, SilentReporter)

		p = %PackagesInstalled{depends: []}
		Runner.converge(p, SilentReporter)

		p = %PackagesInstalled{depends: []}
		Runner.converge(p, SilentReporter)
	end
end
