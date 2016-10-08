alias Gears.FileUtil
alias Converge.Unit

defmodule Converge.PackageIndexUpdated do
	defstruct max_age: 3600
end

defimpl Unit, for: Converge.PackageIndexUpdated do
	def meet(_) do
		{_, 0} = System.cmd("apt-get", ["update"])
	end

	def met?(p) do
		stat = File.stat("/var/cache/apt/pkgcache.bin", time: :posix)
		updated = case stat do
			{:ok, info} -> info.mtime
			{:error, _} -> 0
		end
		now = :os.system_time(:second)
		updated > now - p.max_age
	end
end


defmodule Converge.PackageCacheEmptied do
	defstruct []
end

defimpl Unit, for: Converge.PackageCacheEmptied do
	def meet(_) do
		{_, 0} = System.cmd("apt-get", ["clean"])
	end

	def met?(p) do
		empty_archives = Path.wildcard("/var/cache/apt/archives/*.*") == []
		empty_partial  = Path.wildcard("/var/cache/apt/archives/partial/*.*") == []
		empty_archives and empty_partial
	end
end


defmodule Converge.PackagesInstalled do
	@enforce_keys [:depends]
	defstruct depends: []
end

defimpl Unit, for: Converge.PackagesInstalled do
	@spec make_control(%Converge.PackagesInstalled{}) :: %Debpress.Control{}
	defp make_control(p) do
		%Debpress.Control{
			name:              "converge-packages-installed",
			version:           "0.1",
			architecture:      "all",
			maintainer:        "nobody",
			installed_size_kb: 0,
			depends:           p.depends,
			section:           "metapackages",
			priority:          :optional,
			short_description: "Packages listed in a PackagesInstalled unit in a converge script."
		}
	end

	@spec make_deb(%Converge.PackagesInstalled{}) :: String.t
	defp make_deb(p) do
		temp = FileUtil.temp_dir("converge-packages-installed")
		control_tar_gz = Path.join(temp, "control.tar.gz")

		data_tar_xz = Path.join(temp, "data.tar.xz")
		{_, 0} = System.cmd("tar", ["-cJf", data_tar_xz, "--files-from=/dev/null"])

		deb = Path.join(temp, "converge-packages-installed.deb")
		Debpress.write_control_tar_gz(control_tar_gz, Debpress.control_file(make_control(p)), %{})
		Debpress.write_deb(deb, control_tar_gz, data_tar_xz)
		deb
	end

	defp get_control_line(lines, name) do
		match = lines |> Enum.filter(&(String.starts_with?(&1, "#{name}: "))) |> List.first
		case match do
			nil -> nil
			_   -> match |> String.split(": ", parts: 2) |> List.last
		end
	end

	defp met_identical_package_installed?(p) do
		{out, status} = System.cmd("dpkg-query", ["--status", "converge-packages-installed"])
		case status do
			0 ->
				control = out |> String.split("\n")
				depends = get_control_line(control, "Depends") || ""
				# https://anonscm.debian.org/cgit/dpkg/dpkg.git/tree/lib/dpkg/pkg-namevalue.c#n52
				# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
				installed = get_control_line(control, "Status") == "install ok installed"
				same_depends = depends == p.depends |> Enum.join(", ")
				installed and same_depends
			_ -> false
		end
	end

	defp met_marked_as_manual?() do
		{out, 0} = System.cmd("apt-mark", ["showmanual"])
		installed_manual = out |> String.split("\n") |> Enum.into(MapSet.new())
		installed_manual |> MapSet.member?("converge-packages-installed")
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

	def met?(p) do
		met_identical_package_installed?(p) and
		met_marked_as_manual?() and
		met_nothing_to_fix?()
	end

	def meet(p) do
		deb = make_deb(p)
		env = [
			{"DEBIAN_FRONTEND",          "noninteractive"},
			{"APT_LISTCHANGES_FRONTEND", "none"},
			{"APT_LISTBUGS_FRONTEND",    "none"}
		]
		dpkg_opts = ["-o", "Dpkg::Options::=--force-confdef", "-o", "Dpkg::Options::=--force-confold"]
		# TODO: --allow-downgrades a good idea here?
		{_, 0} = System.cmd("apt-get", ["install", "-y", "--allow-downgrades"] ++ dpkg_opts ++ [deb], env: env)
		{_, 0} = System.cmd("apt-get", ["autoremove", "--purge", "-y", "--allow-downgrades"], env: env)
	end
end
