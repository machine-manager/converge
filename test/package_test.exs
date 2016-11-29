alias Converge.{PackageIndexUpdated, PackageCacheEmptied, MetaPackageInstalled, DanglingPackagesPurged, Runner}
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

		p = %MetaPackageInstalled{name: name, depends: ["fortune-mod", "fortunes-eo"]}
		Runner.converge(p, TestingContext.get_context())
		assert package_installed("fortune-mod")
		assert package_installed("fortunes-eo")

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())

		# Make sure those `depends:` were actually removed
		p = %DanglingPackagesPurged{}
		Runner.converge(p, TestingContext.get_context())
		assert not package_installed("fortune-mod")
		assert not package_installed("fortunes-eo")

		p = %MetaPackageInstalled{name: name, depends: []}
		Runner.converge(p, TestingContext.get_context())
	end

	# Unsafe function only for use by these tests
	defp package_installed(name) do
		{_, code} = System.cmd("sh", ["-c", "dpkg -l | grep -P 'ii\s+#{name}\s+'"])
		case code do
			0 -> true
			1 -> false
		end
	end
end
