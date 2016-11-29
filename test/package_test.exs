alias Converge.{PackageIndexUpdated, PackageCacheEmptied, MetaPackageInstalled, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.PackageIndexUpdatedTest do
	use ExUnit.Case

	test "PackageIndexUpdated" do
		p = %PackageIndexUpdated{}
		Runner.converge(p, TestingContext.get_context())
	end

	test "PackageIndexUpdated with max_age" do
		p = %PackageIndexUpdated{max_age: 1800}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.PackageCacheEmptiedTest do
	use ExUnit.Case

	test "PackageCacheEmptied" do
		p = %PackageCacheEmptied{}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.MetaPackageInstalledTest do
	use ExUnit.Case

	@tag :slow
	test "packages are installed and removed as needed" do
		name = "converge-meta-package-installed-test"

		p = %MetaPackageInstalled{name: name, depends: ["fortune", "fortunes-eo"]}
		Runner.converge(p, TestingContext.get_context())

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())
	end
end
