alias Gears.StringUtil
alias Converge.{
	PackageIndexUpdated, PackageCacheEmptied, PackagesMarkedAutoInstalled,
	PackagesMarkedManualInstalled, DanglingPackagesPurged, PackagePurged,
	MetaPackageInstalled, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.PackageIndexUpdatedTest do
	use ExUnit.Case

	test "package index is updated" do
		p = %PackageIndexUpdated{}
		Runner.converge(p, TestingContext.get_context())
	end

	test "package index is updated when using a max_age" do
		p = %PackageIndexUpdated{max_age: 1800}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.PackageCacheEmptiedTest do
	use ExUnit.Case

	test "package cache is emptied" do
		p = %PackageCacheEmptied{}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.PackagesMarkedAutoInstalledTest do
	use ExUnit.Case

	@tag :slow
	test "packages are marked auto" do
		# setup
		p = %MetaPackageInstalled{name: "converge-pmai-test-1", depends: []}
		Runner.converge(p, TestingContext.get_context())
		p = %MetaPackageInstalled{name: "converge-pmai-test-2", depends: []}
		Runner.converge(p, TestingContext.get_context())

		# test
		p = %PackagesMarkedAutoInstalled{names: ["converge-pmai-test-1", "converge-pmai-test-2"]}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.PackagesMarkedManualInstalledTest do
	use ExUnit.Case

	@tag :slow
	test "packages are marked manual" do
		# setup
		p = %MetaPackageInstalled{name: "converge-pmmi-test", depends: ["fortunes-mario", "fortunes-br"]}
		Runner.converge(p, TestingContext.get_context())

		# test
		p = %PackagesMarkedManualInstalled{names: ["fortunes-mario", "fortunes-br"]}
		Runner.converge(p, TestingContext.get_context())
		p = %PackagesMarkedManualInstalled{names: ["fortunes-mario"]}
		Runner.converge(p, TestingContext.get_context())

		# "cleanup"
		p = %PackagesMarkedAutoInstalled{names: ["converge-pmmi-test", "fortunes-mario", "fortunes-br"]}
		Runner.converge(p, TestingContext.get_context())
		p = %DanglingPackagesPurged{}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.PackagePurgedTest do
	use ExUnit.Case

	@tag :slow
	test "package is purged" do
		# setup
		p = %MetaPackageInstalled{name: "converge-package-purged-test", depends: []}
		Runner.converge(p, TestingContext.get_context())

		# test
		p = %PackagePurged{name: "converge-package-purged-test"}
		Runner.converge(p, TestingContext.get_context())
	end
end


defmodule Converge.MetaPackageInstalledTest do
	use ExUnit.Case

	@tag :slow
	test "packages are installed and removed as needed" do
		name = "converge-meta-package-installed-test"

		p = %MetaPackageInstalled{name: name, depends: ["fortune-mod", "fortunes-eo"]}
		Runner.converge(p, TestingContext.get_context())
		assert package_installed("fortune-mod")
		assert package_installed("fortunes-eo")

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())

		# Make sure the old `depends:` are no longer depended-on by removing
		# autoinstalled packages.
		p = %DanglingPackagesPurged{}
		Runner.converge(p, TestingContext.get_context())
		assert not package_installed("fortune-mod")
		assert not package_installed("fortunes-eo")

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())
	end

	defp package_installed(name) do
		{out, 0} = System.cmd("dpkg", ["-l"])
		lines = StringUtil.grep(out, ~r"^ii\s+#{name}\s+")
		case lines do
			[] -> false
			_  -> true
		end
	end
end
