alias Gears.FileUtil

defmodule Converge.PackagesInstalled do
	@enforce_keys [:depends]
	defstruct depends: nil
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

	defp make_deb(p) :: String.t do
		temp = FileUtil.temp_dir("converge-packages-installed")
		control_tar_gz = Path.join(temp, "control.tar.gz")
		deb = Path.join(temp, "converge-packages-installed.deb")
		write_control_tar_gz(control_tar_gz, control_file(make_control(p), %{})
		write_deb(deb, control_tar_gz)
		deb
	end

	defp get_control_line(s, name) do
		s
			|> Enum.filter(&(String.starts_with?(&1, "${name}: ")))
			|> List.first
			|> String.split(": ", parts: 2)
			|> List.last
	end

	defp met_identical_package_installed?(p) do
		dpkg-query --status ubuntu-mono
		{out, 0} = System.cmd("dpkg-query", "--status", "converge-packages-installed")
		control = out |> String.split("\n")
		depends = get_control_line(control, "Depends")
		# https://github.com/endlessm/dpkg/blob/3340fdbf6169224a63246b508917f531880de433/lib/dpkg/pkg-namevalue.c#L52-L77
		# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
		status = get_control_line(control, "Status")
		met = case status do
			"install ok installed" -> true
			_                      -> false
		end
		met and case depends do
			String.join(p.depends) -> true
			_                      -> false
		end
	end

	defp met_marked_as_manual?() do
		# TODO
		true
	end

	@doc """
	`true` if `apt-get -f install` doesn't need to do anything and there are no
	packages that can be autoremoved.
	"""
	defp met_nothing_to_fix?() do
		{out, 0} = System.cmd("apt-get" ["--simulate", "--fix-broken", "install"])
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
		deb = make_deb()
		{_, 0} = System.cmd("dpkg", ["-i", deb])
		{_, 0} = System.cmd("apt-get", ["--fix-broken", "install"])
		{_, 0} = System.cmd("apt-get", ["autoremove", "--purge"])
	end
end
