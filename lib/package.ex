alias Gears.FileUtil
alias Converge.Unit

defmodule Converge.PackageIndexUpdated do
	@moduledoc """
	The system package manager's package index was updated within
	the last `max_age` seconds.
	"""
	defstruct max_age: 3600
end

defimpl Unit, for: Converge.PackageIndexUpdated do
	def met?(u) do
		stat = File.stat("/var/cache/apt/pkgcache.bin", time: :posix)
		updated = case stat do
			{:ok, info} -> info.mtime
			{:error, _} -> 0
		end
		now = :os.system_time(:second)
		updated > now - u.max_age
	end

	def meet(_, _) do
		{_, 0} = System.cmd("apt-get", ["update"])
	end
end


defmodule Converge.PackageCacheEmptied do
	@moduledoc """
	The system package manager's package cache is empty.
	"""
	defstruct []
end

defimpl Unit, for: Converge.PackageCacheEmptied do
	def met?(_) do
		empty_archives = Path.wildcard("/var/cache/apt/archives/*.*") == []
		empty_partial  = Path.wildcard("/var/cache/apt/archives/partial/*.*") == []
		empty_archives and empty_partial
	end

	def meet(_, _) do
		{_, 0} = System.cmd("apt-get", ["clean"])
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
	def met?(u) do
		met_identical_package_installed?(u) and
		met_marked_as_manual?(u) and
		met_nothing_to_fix?()
	end

	def meet(u, _) do
		deb = make_deb(u)
		env = [
			{"DEBIAN_FRONTEND",          "noninteractive"},
			{"APT_LISTCHANGES_FRONTEND", "none"},
			{"APT_LISTBUGS_FRONTEND",    "none"}
		]
		dpkg_opts = ["-o", "Dpkg::Options::=--force-confdef", "-o", "Dpkg::Options::=--force-confold"]
		{_, 0} = System.cmd("apt-get", ["install", "-y"] ++ dpkg_opts ++ [deb], env: env)
		{_, 0} = System.cmd("apt-get", ["autoremove", "--purge", "-y"], env: env)
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

		data_tar_xz = Path.join(temp, "data.tar.xz")
		{_, 0} = System.cmd("tar", ["-cJf", data_tar_xz, "--files-from=/dev/null"])

		deb = Path.join(temp, "converge-packages-installed.deb")
		Debpress.write_control_tar_gz(control_tar_gz, Debpress.control_file(make_control(u)), %{})
		Debpress.write_deb(deb, control_tar_gz, data_tar_xz)
		deb
	end

	defp met_identical_package_installed?(u) do
		{out, status} = System.cmd("dpkg-query", ["--status", u.name], stderr_to_stdout: true)
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

	defp met_marked_as_manual?(u) do
		{out, 0} = System.cmd("apt-mark", ["showmanual"])
		installed_manual = out |> String.split("\n") |> Enum.into(MapSet.new())
		installed_manual |> MapSet.member?(u.name)
	end

	@docp """
	`true` if `apt-get -f install` doesn't need to do anything and there are no
	packages that can be autoremoved.
	"""
	defp met_nothing_to_fix?() do
		{out, 0} = System.cmd("apt-get", ["--simulate", "--fix-broken", "install"])
		need_autoremove = String.match?(out, ~r"The following packages were automatically installed and are no longer required:")
		actions = out
			|> String.split("\n")
			|> Enum.filter(&(String.match?(&1, ~r"^(Inst|Conf|Remv) ")))
		met = case actions do
			[] -> true
			_  -> false
		end
		met and not need_autoremove
	end

	defp get_control_line(lines, name) do
		match = lines |> Enum.filter(&(String.starts_with?(&1, "#{name}: "))) |> List.first
		case match do
			nil -> nil
			_   -> match |> String.split(": ", parts: 2) |> List.last
		end
	end
end
