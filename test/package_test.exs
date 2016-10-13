alias Converge.{PackageIndexUpdated, PackageCacheEmptied, PackagesInstalled, Runner}
alias Converge.TestHelpers.{SilentReporter}

defmodule Converge.PackageIndexUpdatedTest do
	use ExUnit.Case

	test "PackageIndexUpdated" do
		p = %PackageIndexUpdated{}
		Runner.converge(p, SilentReporter)
	end

	test "PackageIndexUpdated with max_age" do
		p = %PackageIndexUpdated{max_age: 1800}
		Runner.converge(p, SilentReporter)
	end
end


defmodule Converge.PackageCacheEmptiedTest do
	use ExUnit.Case

	test "PackageCacheEmptied" do
		p = %PackageCacheEmptied{}
		Runner.converge(p, SilentReporter)
	end
end


defmodule Converge.PackagesInstalledTest do
	use ExUnit.Case

	@tag :slow
	test "packages are installed and removed as needed" do
		p = %PackagesInstalled{depends: ["fortune", "fortunes-eo"]}
		Runner.converge(p, SilentReporter)

		p = %PackagesInstalled{depends: []}
		Runner.converge(p, SilentReporter)

		p = %PackagesInstalled{depends: []}
		Runner.converge(p, SilentReporter)
	end
end
