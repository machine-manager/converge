alias Gears.StringUtil
alias Converge.{
	PackageCacheEmptied, PackagesMarkedAutoInstalled, PackagesMarkedManualInstalled,
	PackageRoots, DanglingPackagesPurged, PackagePurged, MetaPackageInstalled,
	Runner, All, Util, NoPackagesUnavailableInSource, NoPackagesNewerThanInSource,
	BootstrapPackageInstalled, UnitError}
alias Converge.TestHelpers.TestingContext


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


defmodule Converge.PackageRootsTest do
	use ExUnit.Case

	@tag :slow
	test "PackageRoots" do
		# Save information about which packages are marked auto and manual so that
		# we can restore these markings after running the test.
		originally_manual = Util.get_packages_marked(:manual)
		originally_auto   = Util.get_packages_marked(:auto)
		try do
			# Assume that the test machine was configured with converge + base_system
			p = %PackageRoots{names: ["converge-desired-packages"]}
			Runner.converge(p, TestingContext.get_context())
		after
			cleanup = %All{units: [
				%PackagesMarkedManualInstalled{names: originally_manual},
				%PackagesMarkedAutoInstalled{names: originally_auto},
			]}
			Runner.converge(cleanup, TestingContext.get_context())
		end
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


defmodule Converge.BootstrapPackageInstalledTest do
	use ExUnit.Case

	test "bootstrap package" do
		# setup
		p = %PackagePurged{name: "dummy"}
		Runner.converge(p, TestingContext.get_context())

		# test
		b = %BootstrapPackageInstalled{name: "dummy", deb_content: File.read!(Path.join(__DIR__, "packages/dummy_1.0.1.deb"))}
		Runner.converge(b, TestingContext.get_context())
	end

	test "inspect shows content length, not contents" do
		u = %BootstrapPackageInstalled{name: "dummy", deb_content: "abc"}
		assert inspect(u) == ~s(%Converge.BootstrapPackageInstalled{name: "dummy", deb_content: 3 bytes})
	end
end


defmodule Converge.NoPackagesUnavailableInSourceTest do
	use ExUnit.Case

	test "NoPackagesUnavailableInSource can be met" do
		u = %NoPackagesUnavailableInSource{whitelist_regexp: ~r/^(dummy|converge-.*|linux-(image|tools|headers)-.*)$/}
		Runner.converge(u, TestingContext.get_context())
	end

	test "NoPackagesUnavailableInSource can raise UnitError" do
		u = %NoPackagesUnavailableInSource{whitelist_regexp: ~r/^$/}
		assert_raise UnitError, ~r/installed packages that are unavailable in any package source/,
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end
end


defmodule Converge.NoPackagesNewerThanInSourceTest do
	use ExUnit.Case

	test "NoPackagesNewerThanInSource can raise UnitError" do
		{_, 0} = System.cmd("wget", ["-q", "http://ftp.us.debian.org/debian/pool/main/d/dstat/dstat_0.7.3-1_all.deb", "-O", "/tmp/dstat.deb"])
		{_, 0} = System.cmd("dpkg", ["-i", "/tmp/dstat.deb"], stderr_to_stdout: true)

		u = %NoPackagesNewerThanInSource{whitelist_regexp: ~r/^$/}
		assert_raise UnitError, ~r/installed packages that are newer than available in package sources/,
			fn -> Runner.converge(u, TestingContext.get_context()) end
	end

	test "NoPackagesNewerThanInSource can be met" do
		u = %NoPackagesNewerThanInSource{whitelist_regexp: ~r/^dstat/}
		Runner.converge(u, TestingContext.get_context())
	end
end
