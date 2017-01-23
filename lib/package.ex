alias Gears.{FileUtil, StringUtil}
alias Converge.Unit
import Converge.Util, only: [get_control_line: 2]

defmodule Converge.PackageIndexUpdated do
	@moduledoc """
	The system package manager's package index was updated within
	the last `max_age` seconds.
	"""
	defstruct max_age: 3600
end

defimpl Unit, for: Converge.PackageIndexUpdated do
	@moduledoc """
	The system package manager's package index was updated within the last
	`max_age` seconds.

	If you need to clear the cached package index manually (e.g. inside an
	`AfterMeet` after updating `/etc/apt/sources.list`, call
	`Converge.Util.remove_cached_package_index()`.
	"""
	def met?(u, _ctx) do
		stat = File.stat("/var/cache/apt/pkgcache.bin", time: :posix)
		updated = case stat do
			{:ok, info} -> info.mtime
			{:error, _} -> 0
		end
		now = :os.system_time(:second)
		updated > now - u.max_age
	end

	def meet(_, _) do
		# `stderr_to_stdout: true` so that this message is not shown:
		# "AppStream cache update completed, but some metadata was ignored due to errors."
		{_, 0} = System.cmd("apt-get", ["update"], stderr_to_stdout: true)
	end
end


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
end


defmodule Converge.DanglingPackagesPurged do
	@moduledoc """
	All auto-installed packages that are no longer depended-on are purged.
	"""
	defstruct []
end

defimpl Unit, for: Converge.DanglingPackagesPurged do
	def met?(_, _ctx) do
		{out, 0} = System.cmd("apt-get", ["autoremove", "--purge", "--simulate"])
		actions = StringUtil.grep(out, ~r"^Purg ")
		case actions do
			[] -> true
			_  -> false
		end
	end

	def meet(_, _) do
		{_, 0} = System.cmd("apt-get", ["autoremove", "--purge", "-y"])
	end
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
		{out, 0} = System.cmd("apt-mark", ["showauto"])
		installed_auto = out |> String.split("\n") |> MapSet.new
		diff = MapSet.difference(MapSet.new(u.names), installed_auto)
		MapSet.size(diff) == 0
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("apt-mark", ["auto", "--"] ++ u.names)
	end
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
		{out, 0} = System.cmd("apt-mark", ["showmanual"])
		installed_manual = out |> String.split("\n") |> MapSet.new
		diff = MapSet.difference(MapSet.new(u.names), installed_manual)
		MapSet.size(diff) == 0
	end

	def meet(u, _ctx) do
		{_, 0} = System.cmd("apt-mark", ["manual", "--"] ++ u.names)
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
		{_, 0} = System.cmd("apt-get", ["remove", "--purge", "-y", "--", u.name])
	end
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
		deb = make_deb(u)
		env = [
			{"DEBIAN_FRONTEND",          "noninteractive"},
			{"APT_LISTCHANGES_FRONTEND", "none"},
			{"APT_LISTBUGS_FRONTEND",    "none"}
		]
		args = [
			# This is the only reasonable behavior, both to reduce our exposure to
			# security bugs, and because when the recommends are missing, apt will
			# not automatically install them.  If you want any of the recommended
			# packages, list them in the `depends` for this unit.
			"--no-install-recommends",
			# --force-confold, when combined with --force-confdef, will overwrite
			# a configuration file only if it has not been modified from the
			# package default.
			"-o", "Dpkg::Options::=--force-confdef",
			"-o", "Dpkg::Options::=--force-confold",
		]
		{_, 0} = System.cmd("apt-get", ["install", "-y"] ++ args ++ ["--", deb], env: env)
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
				control = out |> String.split("\n")
				depends = get_control_line(control, "Depends") || ""
				# https://anonscm.debian.org/cgit/dpkg/dpkg.git/tree/lib/dpkg/pkg-namevalue.c#n52
				# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
				installed = get_control_line(control, "Status") == "install ok installed"
				same_depends = depends == u.depends |> Enum.join(", ")
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
end
