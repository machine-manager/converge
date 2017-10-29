alias Gears.FileUtil
alias Converge.{Unit, Runner, FilePresent, Util}

defmodule Converge.GPGSimpleKeyring do
	@moduledoc """
	A GPG simple keyring (not GPG2 keybox) file exists at `path` and contains
	just keys `keys` (a list of strings, one unarmored key per string).  Passes
	`mode`, `immutable`, `user`, and `group` through to `FilePresent`.

	The simple keyring format is used to make the output usable with apt
	on xenial, which does not support the GPG2 keybox format:
	https://lists.debian.org/deity/2016/11/msg00073.html
	"""
	@enforce_keys [:path, :keys, :mode]
	defstruct path: nil, keys: [], mode: nil, immutable: false, user: nil, group: nil
end

defimpl Unit, for: Converge.GPGSimpleKeyring do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		content = Enum.join(u.keys)
		%FilePresent{path: u.path, content: content, mode: u.mode, immutable: u.immutable, user: u.user, group: u.group}
	end
end

defimpl Inspect, for: Converge.GPGSimpleKeyring do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		count = u.keys |> length
		concat([
			color("%Converge.GPGSimpleKeyring{", :map, opts),
			color("path: ",      :atom, opts),
			to_doc(u.path,              opts),
			color(", ",          :map,  opts),
			color("keys: ",      :atom, opts),
			counted_noun(count, "key", "keys"),
			color(", ",          :map,  opts),
			color("mode: ",      :atom, opts),
			to_doc(u.mode, %Inspect.Opts{opts | base: :octal}),
			color(", ",          :map,  opts),
			color("immutable: ", :atom, opts),
			to_doc(u.immutable,         opts),
			color(", ",          :map,  opts),
			color("user: ",      :atom, opts),
			to_doc(u.user,              opts),
			color(", ",          :map,  opts),
			color("group: ",     :atom, opts),
			to_doc(u.group,             opts),
			color("}",           :map,  opts)
		])
	end
end

defmodule Converge.GPGKeybox do
	@moduledoc """
	A GPG2 keybox file exists at `path` and contains just keys `keys` (a list of
	strings, one unarmored key per string).  Passes `mode`, `immutable`, `user`,
	and `group` through to `FilePresent`.

	Use GPGKeybox for /etc/apt/trusted.gpg on stretch because it does not support
	simple keyrings.
	"""
	@enforce_keys [:path, :keys, :mode]
	defstruct path: nil, keys: [], mode: nil, immutable: false, user: "root", group: "root"
end

defimpl Unit, for: Converge.GPGKeybox do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		content = get_keybox_content(u.keys)
		%FilePresent{path: u.path, content: content, mode: u.mode, immutable: u.immutable, user: u.user, group: u.group}
	end

	defp get_keybox_content(keys) do
		maybe_install_gnug2()
		keybox_file = FileUtil.temp_path("converge-gpg2-keybox")
		# Create an empty keybox, because `keys` may be empty
		create_empty_keybox(keybox_file)
		for key <- keys do
			key_file = FileUtil.temp_path("converge-gpg2-key")
			File.write!(key_file, key)
			{"", 0} = System.cmd("gpg2", get_gpg_opts(keybox_file) ++ ["--import", key_file])
			FileUtil.rm_f!(key_file)
		end
		content = File.read!(keybox_file)
		FileUtil.rm_f!(keybox_file)
		content
	end

	defp maybe_install_gnug2() do
		unless File.exists?("/usr/bin/gpg2") do
			Util.update_package_index()
			Util.install_package("gnupg2")
		end
	end

	defp create_empty_keybox(keybox_file) do
		{"gpg: no valid OpenPGP data found.\n", 2} =
			System.cmd("gpg2", get_gpg_opts(keybox_file) ++ ["--import", "/dev/null"], stderr_to_stdout: true)
	end

	defp get_gpg_opts(keybox_file) do
		[
			"--quiet",
			"--no-options",
			"--ignore-time-conflict",
			# This also avoids creating a ~/.gnupg/trustdb.gpg
			"--trust-model", "direct",
			"--no-auto-check-trustdb",
			"--no-default-keyring",
			"--primary-keyring", keybox_file,
		]
	end
end

defimpl Inspect, for: Converge.GPGKeybox do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		count = u.keys |> length
		concat([
			color("%Converge.GPGKeybox{", :map, opts),
			color("path: ",      :atom, opts),
			to_doc(u.path,              opts),
			color(", ",          :map,  opts),
			color("keys: ",      :atom, opts),
			counted_noun(count, "key", "keys"),
			color(", ",          :map,  opts),
			color("mode: ",      :atom, opts),
			to_doc(u.mode, %Inspect.Opts{opts | base: :octal}),
			color(", ",          :map,  opts),
			color("immutable: ", :atom, opts),
			to_doc(u.immutable,         opts),
			color(", ",          :map,  opts),
			color("user: ",      :atom, opts),
			to_doc(u.user,              opts),
			color(", ",          :map,  opts),
			color("group: ",     :atom, opts),
			to_doc(u.group,             opts),
			color("}",           :map,  opts)
		])
	end
end
