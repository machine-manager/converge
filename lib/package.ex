alias Gears.{FileUtil, StringUtil}
alias Converge.{FilePresent, Unit, Util, Runner, All, UnitError}

defmodule Converge.PackageCacheEmptied do
	@moduledoc """
	The system package manager's package cache is empty.
	"""
	defstruct []
end

defimpl Unit, for: Converge.PackageCacheEmptied do
	def met?(_, _ctx) do
		empty_archives = Path.wildcard("/var/cache/apt/archives/*.*") == []
		empty_partial  = Path.wildcard("/var/cache/apt/archives/partial/*.*") == []
		empty_archives and empty_partial
	end

	def meet(_, _) do
		{_, 0} = System.cmd("apt-get", ["clean"])
	end

	def package_dependencies(_, _release), do: ["apt"]
end


defmodule Converge.DanglingPackagesPurged do
	@moduledoc """
	All auto-installed packages that are no longer depended-on are purged.
	All packages that are mere recommends or suggests are purged.

	Caveat: when used in combination with `PackageRoots`, this unit will not
	result in the purging of absolutely all unnecessary packages because
		1) apt may assume that every package providing some virtual package is
		   still necessary.
		2) /etc/apt/apt.conf.d/01autoremove-kernels will prevent the removal of
		   some linux-* packages.
		3) autoremove doesn't properly remove some base set of foreign architecture
		   packages.
	"""
	defstruct []
end

defimpl Unit, for: Converge.DanglingPackagesPurged do
	def met?(_, _ctx) do
		Util.dpkg_configure_pending()
		{out, 0} = System.cmd("apt-get", get_purge_args() ++ ["--simulate"])
		actions = StringUtil.grep(out, ~r"^Purg ")
		case actions do
			[] -> true
			_  -> false
		end
	end

	def meet(_, _) do
		Util.dpkg_configure_pending()
		{_, 0} = System.cmd("apt-get", get_purge_args() ++ ["-y"],
		                    env: Util.get_noninteractive_apt_env(), stderr_to_stdout: true)
	end

	defp get_purge_args() do
		[
			"autoremove",
			"-o", "APT::AutoRemove::RecommendsImportant=false",
			"-o", "APT::AutoRemove::SuggestsImportant=false",
			"--purge",
		]
	end

	def package_dependencies(_, _release), do: ["dpkg", "apt"]
end


defmodule Converge.PackagesMarkedAutoInstalled do
	@moduledoc """
	Packages `names` are marked auto-installed (if nothing depends on them,
	they will be automatically removed by `apt-get autoremove`).
	"""
	@enforce_keys [:names]
	defstruct names: []
end

defimpl Unit, for: Converge.PackagesMarkedAutoInstalled do
	def met?(u, _ctx) do
		installed_auto = Util.get_packages_marked(:auto)
		diff = MapSet.difference(MapSet.new(u.names), installed_auto)
		MapSet.size(diff) == 0
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("apt-mark", ["auto", "--" | Enum.into(u.names, [])])
	end

	def package_dependencies(_, _release), do: ["apt"]
end


defmodule Converge.PackagesMarkedManualInstalled do
	@moduledoc """
	Packages `names` are marked manual-installed (they will not be automatically
	removed by `apt-get autoremove`).
	"""
	@enforce_keys [:names]
	defstruct names: []
end

defimpl Unit, for: Converge.PackagesMarkedManualInstalled do
	def met?(u, _ctx) do
		installed_manual = Util.get_packages_marked(:manual)
		diff = MapSet.difference(MapSet.new(u.names), installed_manual)
		MapSet.size(diff) == 0
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("apt-mark", ["manual", "--" | Enum.into(u.names, [])])
	end

	def package_dependencies(_, _release), do: ["apt"]
end


defmodule Converge.PackageRoots do
	@moduledoc """
	Packages `names` are marked manual-installed and all other installed
	packages are marked auto-installed.
	"""
	@enforce_keys [:names]
	defstruct names: []
end

defimpl Unit, for: Converge.PackageRoots do
	alias Converge.{PackagesMarkedAutoInstalled, PackagesMarkedManualInstalled}

	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		packages_wrongly_marked_manual =
			MapSet.difference(Util.get_packages_marked(:manual), MapSet.new(u.names))
		%All{units: [
			%PackagesMarkedManualInstalled{names: u.names},
			%PackagesMarkedAutoInstalled{names: packages_wrongly_marked_manual},
		]}
	end

	def package_dependencies(_, release) do
		Converge.Unit.package_dependencies(%{__struct__: PackagesMarkedAutoInstalled}, release) ++
		Converge.Unit.package_dependencies(%{__struct__: PackagesMarkedManualInstalled}, release)
	end
end


defmodule Converge.PackagePurged do
	@moduledoc """
	Package `name` is removed and purged (no configuration files left behind).
	"""
	@enforce_keys [:name]
	defstruct name: nil
end

defimpl Unit, for: Converge.PackagePurged do
	def met?(u, _ctx) do
		{out, status} = System.cmd("dpkg-query", ["--status", "--", u.name], stderr_to_stdout: true)
		case status do
			1 ->
				String.match?(out, ~r"""
					^dpkg-query: package '#{u.name}' is not installed \
					and no information is available\
					""")
			_ -> false
		end
	end

	def meet(u, _) do
		Util.dpkg_configure_pending()
		{_, 0} = System.cmd("apt-get", ["remove", "--purge", "-y", "--", u.name],
		                    env: Util.get_noninteractive_apt_env(), stderr_to_stdout: true)
	end

	def package_dependencies(_, _release), do: ["dpkg", "apt"]
end


defmodule Converge.MetaPackageInstalled do
	@moduledoc """
	A metapackage (one that just depends on other packages) is installed.

	This is the recommended way to install packages.  Packages that were listed
	in a MetaPackageInstalled unit, then removed, will be automatically removed
	the next time the unit is run.
	"""
	@enforce_keys [:name, :depends]
	defstruct name: nil, depends: []
end

defimpl Unit, for: Converge.MetaPackageInstalled do
	def met?(u, _ctx) do
		met_identical_package_installed?(u) and
		met_nothing_to_fix?()
	end

	def meet(u, _) do
		Util.dpkg_configure_pending()
		# Make sure amd64 machines also have access to i386 packages
		{_, 0} = System.cmd("dpkg", ["--add-architecture", "i386"])
		Util.update_package_index()

		# capture stderr because apt outputs
		# "N: Ignoring file '50unattended-upgrades.ucf-dist' in directory '/etc/apt/apt.conf.d/'
		#  as it has an invalid filename extension"
		{_, 0} = System.cmd("apt-get", Util.get_apt_install_args() ++ ["install", "--", make_deb(u)],
		                    env: Util.get_noninteractive_apt_env(), stderr_to_stdout: true)
	end

	@spec make_control(%Converge.MetaPackageInstalled{}) :: %Debpress.Control{}
	defp make_control(u) do
		%Debpress.Control{
			name:              u.name,
			version:           "1.#{:os.system_time(:millisecond)}",
			architecture:      "all",
			maintainer:        "nobody",
			installed_size_kb: 0,
			depends:           u.depends,
			section:           "metapackages",
			priority:          :optional,
			short_description: "package depending on packages listed in a Converge.MetaPackageInstalled unit"
		}
	end

	@spec make_deb(%Converge.MetaPackageInstalled{}) :: String.t
	defp make_deb(u) do
		temp = FileUtil.temp_dir(u.name)
		control_tar_gz = Path.join(temp, "control.tar.gz")

		data_tar_gz = Path.join(temp, "data.tar.gz")
		{_, 0} = System.cmd("tar", ["-czf", data_tar_gz, "--files-from=/dev/null"])

		deb = Path.join(temp, "metapackage.deb")
		Debpress.write_control_tar_gz(control_tar_gz, Debpress.control_file(make_control(u)), %{})
		Debpress.write_deb(deb, control_tar_gz, data_tar_gz)
		deb
	end

	defp met_identical_package_installed?(u) do
		{out, status} = System.cmd("dpkg-query", ["--status", "--", u.name], stderr_to_stdout: true)
		case status do
			0 ->
				control = String.split(out, "\n")
				depends = Util.get_control_line(control, "Depends") || ""
				# https://anonscm.debian.org/cgit/dpkg/dpkg.git/tree/lib/dpkg/pkg-namevalue.c#n52
				# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
				installed = Util.get_control_line(control, "Status") == "install ok installed"
				same_depends = depends == Enum.join(u.depends, ", ")
				installed and same_depends
			_ -> false
		end
	end

	# Returns `true` if `apt-get -f install` doesn't need to do anything.
	defp met_nothing_to_fix?() do
		{out, 0} = System.cmd("apt-get", ["--simulate", "--fix-broken", "install"])
		actions = StringUtil.grep(out, ~r"^(Inst|Conf|Remv) ")
		case actions do
			[] -> true
			_  -> false
		end
	end

	# make_deb requires ar from binutils
	def package_dependencies(_, _release), do: ["binutils", "dpkg", "apt"]
end


defmodule Converge.BootstrapPackageInstalled do
	@moduledoc """
	A package with a given name is installed.

	`meet` on this unit will install the package using `deb_content` which must be
	a string containing a .deb file.

	Useful for embedded .deb files in a role, in the rare case where that is useful.
	"""
	@enforce_keys [:name, :deb_content]
	defstruct name: nil, deb_content: []
end

defimpl Unit, for: Converge.BootstrapPackageInstalled do
	def met?(u, _ctx) do
		{out, status} = System.cmd("dpkg-query", ["--status", "--", u.name], stderr_to_stdout: true)
		case status do
			0 ->
				control = String.split(out, "\n")
				Util.get_control_line(control, "Status") == "install ok installed"
			_ -> false
		end
	end

	def meet(u, ctx) do
		deb_path = FileUtil.temp_path("Converge.BootstrapPackageInstalled", "deb")
		f = %FilePresent{path: deb_path, content: u.deb_content, mode: 0o600}
		Runner.converge(f, ctx)
		Util.install_package(deb_path)
	end

	def package_dependencies(_, _release), do: ["apt"]
end

defimpl Inspect, for: Converge.BootstrapPackageInstalled do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		len = byte_size(u.deb_content)
		concat([
			color("%Converge.BootstrapPackageInstalled{", :map, opts),
			color("name: ",        :atom, opts),
			to_doc(u.name,                opts),
			color(", ",            :map,  opts),
			color("deb_content: ", :atom, opts),
			counted_noun(len, "byte", "bytes"),
			color("}",             :map,  opts),
		])
	end
end


defmodule Converge.NoPackagesUnavailableInSource do
	@moduledoc """
	No installed packages are unavailable in any package source.

	Package names matched by `whitelist_regexp` will be allowed despite not
	being in any package source.

	`meet` on this unit just raises `UnitError` because this unit being unmet
	is a rare situation that warrants manual inspection.
	"""
	@enforce_keys [:whitelist_regexp]
	defstruct whitelist_regexp: ~r/^$/
end

defimpl Unit, for: Converge.NoPackagesUnavailableInSource do
	def met?(u, _ctx) do
		get_unexpected_packages(u) == []
	end

	def meet(u, _) do
		raise(UnitError, """
			System has installed packages that are unavailable in any package source: \
			#{inspect get_unexpected_packages(u)}\
			""")
	end

	# Get packages that are not present in any package source and are not
	# whitelisted.
	defp get_unexpected_packages(u) do
		{out, 0} = System.cmd("aptitude", ["search", "-F", "%p", "?obsolete"])
		out
		|> String.split
		|> Enum.reject(fn package -> package =~ u.whitelist_regexp end)
	end

	def package_dependencies(_, _release), do: ["aptitude"]
end


defmodule Converge.NoPackagesNewerThanInSource do
	@moduledoc """
	No installed packages are newer than the highest version available in the
	package sources.

	Package names matched by `whitelist_regexp` will be allowed despite being
	newer.

	`meet` on this unit just raises `UnitError` because this unit not being met
	is a rare situation that typically warrants manual inspection.
	"""
	@enforce_keys [:whitelist_regexp]
	defstruct whitelist_regexp: ~r/^$/
end

defimpl Unit, for: Converge.NoPackagesNewerThanInSource do
	def met?(u, _ctx) do
		get_unexpected_packages(u) == []
	end

	def meet(u, _) do
		raise(UnitError, """
			System has installed packages that are newer than available in package sources: \
			#{inspect get_unexpected_packages(u)}\
			""")
	end

	defp get_unexpected_packages(u) do
		{out, 0} = System.cmd("apt-show-versions", [])
		out
		|> StringUtil.grep(~r/ newer than version in archive$/)
		|> Enum.map(fn line -> [package, version | _] = String.split(line); {package, version} end)
		|> Enum.reject(fn {package, _} -> package =~ u.whitelist_regexp end)
	end

	def package_dependencies(_, _release), do: ["apt-show-versions"]
end
