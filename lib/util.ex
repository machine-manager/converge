alias Gears.FileUtil

defmodule Converge.TagValueError do
	defexception [:message]
end

defmodule Converge.Util do
	@moduledoc """
	Helper functions used by base_system and roles.
	"""

	@doc """
	Returns a map with information from /proc/meminfo.  Note that any kB values
	are given as bytes, not as kB.
	"""

	alias Converge.TagValueError

	def get_meminfo() do
		# Need cat because File.read! and :file.read_file return "" because
		# procfs says the file has a size of 0.
		{out, 0} = System.cmd("cat", ["/proc/meminfo"])
		out
		|> String.replace_suffix("\n", "")
		|> String.split("\n")
		|> Enum.map(fn line ->
			case String.split(line, ~r/:?\s+/, parts: 3) do
				[label, number, "kB"] -> {label, String.to_integer(number) * 1024}
				[label, number]       -> {label, String.to_integer(number)}
			end
		end)
		|> Enum.into(%{})
	end

	def get_cpuinfo() do
		{out, 0} = System.cmd("lscpu", [])
		info = out
			|> String.replace_suffix("\n", "")
			|> String.split("\n")
			|> Enum.map(fn line -> line |> String.split(~r/:\s+/, parts: 2) |> List.to_tuple end)
			|> Enum.into(%{})
		%{
			sockets:           int(info["Socket(s)"]),
			cores:             int(info["Socket(s)"]) * int(info["Core(s) per socket"]),
			threads:           int(info["CPU(s)"]),
			architecture:      info["Architecture"],
			vendor_id:         info["Vendor ID"],
			hypervisor_vendor: info["Hypervisor vendor"],
			model:             int(info["Model"]),
			model_name:        info["Model name"],
			stepping:          int(info["Stepping"]),
			cpu_mhz:           float(info["CPU MHz"]),
			cpu_max_mhz:       float(info["CPU max MHz"]),
			cpu_min_mhz:       float(info["CPU min MHz"]),
			flags:             String.split(info["Flags"], " "),
		}
	end

	defp int(nil),   do: nil
	defp int(s),     do: String.to_integer(s)
	defp float(nil), do: nil
	defp float(s),   do: String.to_float(s)

	@doc false
	def get_control_line(lines, name) do
		match = lines |> Enum.filter(&(String.starts_with?(&1, "#{name}: "))) |> List.first
		case match do
			nil -> nil
			_   -> match |> String.split(": ", parts: 2) |> List.last
		end
	end

	def systemd_unit_active?(name) do
		case System.cmd("systemctl", ["-q", "is-active", "--", name], stderr_to_stdout: true) do
			{_, 0} -> true
			{_, 3} -> false
		end
	end

	def systemd_unit_reload_or_restart_if_active(name) do
		if systemd_unit_active?(name) do
			{_, 0} = System.cmd("systemctl", ["try-reload-or-restart", "--", name])
		end
	end

	def get_packages_marked(:manual) do
		{out, 0} = System.cmd("apt-mark", ["showmanual"])
		out |> String.trim_trailing("\n") |> String.split("\n") |> MapSet.new
	end

	def get_packages_marked(:auto) do
		{out, 0} = System.cmd("apt-mark", ["showauto"])
		out |> String.trim_trailing("\n") |> String.split("\n") |> MapSet.new
	end

	def wait_for_apt_lock() do
		{_, 0} = System.cmd("bash", ["-c", ~s(while fuser /var/lib/apt/lists/lock > /dev/null 2>&1; do echo "Waiting for apt lock..." >&2; sleep 1; done)])
	end

	def wait_for_dpkg_lock() do
		{_, 0} = System.cmd("bash", ["-c", ~s(while fuser /var/lib/dpkg/lock > /dev/null 2>&1; do echo "Waiting for dpkg lock..." >&2; sleep 1; done)])
	end

	@doc """
	Call this before you do anything else with dpkg (it can require it),
	because the last dpkg run may have been aborted and left packages in
	an unconfigured state.
	"""
	def dpkg_configure_pending() do
		{_, 0} = System.cmd("dpkg", ["--configure", "-a"])
	end

	def update_package_index() do
		# `stderr_to_stdout: true` so that this message is not shown:
		# "AppStream cache update completed, but some metadata was ignored due to errors."
		case System.cmd("apt-get", ["update"], stderr_to_stdout: true) do
			{_, 0}      -> nil
			{out, code} -> raise("apt-get update returned exit code #{code} and output #{inspect out}")
		end
	end

	@doc """
	Returns `true` if package `name` is installed, otherwise `false`.
	"""
	def installed?(name) do
		{out, status} = System.cmd("dpkg-query", ["--status", "--", name], stderr_to_stdout: true)
		case status do
			0 ->
				control = String.split(out, "\n")
				# https://anonscm.debian.org/cgit/dpkg/dpkg.git/tree/lib/dpkg/pkg-namevalue.c#n52
				# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
				get_control_line(control, "Status") == "install ok installed"
			_ -> false
		end
	end

	def install_package(name) do
		args = get_apt_install_args() ++ ["install", "--", name]
		{_, 0} = System.cmd("apt-get", args, stderr_to_stdout: true, env: get_noninteractive_apt_env())
	end

	def get_noninteractive_apt_env() do
		[
			{"DEBIAN_FRONTEND",          "noninteractive"},
			{"APT_LISTCHANGES_FRONTEND", "none"},
			{"APT_LISTBUGS_FRONTEND",    "none"}
		]
	end

	def get_apt_install_args() do
		[
			"--assume-yes",
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
	end

	def remove_cached_package_index() do
		FileUtil.rm_f!("/var/cache/apt/pkgcache.bin")
	end

	def get_hostname() do
		File.read!("/etc/hostname") |> String.trim_trailing
	end

	# Not necessarily the "WAN" IP when behind a NAT
	def get_internet_source_ip() do
		{out, 0} = System.cmd("ip", ["route", "get", "8.8.8.8"])
		out
		|> String.split("\n")
		|> hd
		|> String.split
		|> List.last
	end

	@doc """
	@external_resource is used to tell mix which resource files affect the build
	output.  But typing them all out is annoying if you have many files.  This
	macro will walk `path` and declare every file in it an external resource.
	"""
	defmacro declare_external_resources(path) do
		quote do
			{out, 0} = System.cmd("find", [unquote(path), "-type", "f", "-print0"])
			files = out
				|> String.replace_suffix("\0", "")
				|> String.split("\0")
			for f <- files do
				@external_resource f
			end
		end
	end

	defmacro conf_dir(p, mode \\ 0o755, opts \\ []) do
		immutable = opts[:immutable] || false
		quote do
			%Converge.DirectoryPresent{path: unquote(p), mode: unquote(mode), immutable: unquote(immutable)}
		end
	end

	defmacro conf_file(p, mode \\ 0o644, opts \\ []) do
		immutable = opts[:immutable] || false
		data      = File.read!("files/" <> p)
		quote do
			%Converge.FilePresent{path: unquote(p), content: unquote(data), mode: unquote(mode), immutable: unquote(immutable)}
		end
	end

	defmacro content(filename) do
		File.read!(filename)
	end

	defmacro path_expand_content(filename) do
		File.read!(Path.expand(filename))
	end

	def tag_value!(tags, prefix) do
		case tag_value(tags, prefix) do
			nil   -> raise(TagValueError, "No tag with prefix #{inspect prefix} in #{inspect tags}")
			other -> other
		end
	end

	def tag_value(tags, prefix) do
		case tag_values(tags, prefix) do
			[]       -> nil
			[value]  -> value
			multiple -> raise(TagValueError, "Multiple tags with prefix #{inspect prefix}: #{inspect multiple}")
		end
	end

	def tag_values(tags, prefix) do
		tags
		|> Enum.filter(fn tag -> String.starts_with?(tag, prefix <> ":") end)
		|> Enum.map(fn tag -> [^prefix, value] = String.split(tag, ":", parts: 2); value end)
	end

	defmacro marker(basename) do
		quote do
			directory = Path.join("/tmp/converge/markers", Atom.to_string(__MODULE__))
			Path.join(directory, unquote(basename))
		end
	end
end
