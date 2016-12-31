alias Gears.FileUtil

defmodule Converge.Util do
	@doc """
	Returns a map with information from /proc/meminfo.  Note that any kB values
	are given as bytes, not as kB.
	"""
	def get_meminfo() do
		# Need cat because File.read! and :file.read_file return "" because
		# procfs says the file has a size of 0.
		{out, 0} = System.cmd("cat", ["/proc/meminfo"])
		out
		|> String.replace_suffix("\n", "")
		|> String.split("\n")
		|> Enum.map(fn line ->
			case line |> String.split(~r/\s+/) do
				[label, number, "kB"] ->
					{label |> String.replace_suffix(":", ""), (number |> String.to_integer) * 1024}
				[label, number] ->
					{label |> String.replace_suffix(":", ""),  number |> String.to_integer}
			end
		end)
		|> Enum.into(%{})
	end

	@doc false
	def get_control_line(lines, name) do
		match = lines |> Enum.filter(&(String.starts_with?(&1, "#{name}: "))) |> List.first
		case match do
			nil -> nil
			_   -> match |> String.split(": ", parts: 2) |> List.last
		end
	end

	@doc """
	Returns `true` if package `name` is installed, otherwise `false`.
	"""
	def installed?(name) do
		{out, status} = System.cmd("dpkg-query", ["--status", "--", name], stderr_to_stdout: true)
		case status do
			0 ->
				control = out |> String.split("\n")
				# https://anonscm.debian.org/cgit/dpkg/dpkg.git/tree/lib/dpkg/pkg-namevalue.c#n52
				# http://manpages.ubuntu.com/manpages/precise/man1/dpkg.1.html
				get_control_line(control, "Status") == "install ok installed"
			_ -> false
		end
	end

	def remove_cached_package_index() do
		FileUtil.rm_f!("/var/cache/apt/pkgcache.bin")
	end

	@country_file "/etc/country"

	@doc """
	Determines which country this server is located in, returning a lowercase
	two-letter country code.

	Writes the cached country to `/etc/country` so that we don't have to ask
	the Internet again.
	"""
	def get_country() do
		case File.read(@country_file) do
			{:ok, content} -> content |> String.trim_trailing
			_              ->
				{out, 0} = System.cmd("curl", ["-q", "--silent", "http://freegeoip.net/json/"])
				country =
					Regex.run(~r/"country_code": ?"(..)"/, out, capture: :all_but_first)
					|> hd
					|> String.downcase
				File.write(@country_file, country)
				File.chmod!(@country_file, 0o644)
				country
		end
	end

	def get_hostname() do
		File.read!("/etc/hostname") |> String.trim_trailing
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
end
