alias Gears.FileUtil
alias Converge.{Unit, Runner, FilePresent}

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

	def package_dependencies(_, _release), do: []
end

defimpl Inspect, for: Converge.GPGSimpleKeyring do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		count = length(u.keys)
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
		keybox_file = FileUtil.temp_path("converge-gpg2-keybox")
		# Create an empty keybox, because `keys` may be empty
		create_empty_keybox(keybox_file)
		for key <- keys do
			key_file = FileUtil.temp_path("converge-gpg2-key")
			File.write!(key_file, key)
			{_, 0} = faketime_gpg2_import(keybox_file, key_file)
			FileUtil.rm_f!(key_file)
		end
		content = File.read!(keybox_file)
		FileUtil.rm_f!(keybox_file)
		content
	end

	defp create_empty_keybox(keybox_file) do
		{"gpg: no valid OpenPGP data found.\n", 2} = faketime_gpg2_import(keybox_file, "/dev/null")
	end

	defp faketime_gpg2_import(keybox_file, key_file) do
		homedir = FileUtil.temp_dir("converge_gpg_homedir")
		File.chmod!(homedir, 0o700)
		try do
			# Use faketime because gnupg2 --faked-system-time=0 doesn't make the `created-at:`
			# and `last-maint:` timestamps on the keybox deterministic.  Note that we also
			# need to stop the clock with "x0" because otherwise the time may be 1 instead of
			# 0 by the time gnupg2 makes a call to get the time.
			epoch = "1970-01-01 00:00:00"
			args = ["-f", "#{epoch} x0", "gpg2"] ++ get_gpg_opts(keybox_file, homedir) ++ ["--import", key_file]
			System.cmd("faketime", args, stderr_to_stdout: true)
		after
			File.rmdir!(homedir)
		end
	end

	defp get_gpg_opts(keybox_file, homedir) do
		[
			"--quiet",
			# Don't read options from ~/.gnupg
			"--no-options",
			"--ignore-time-conflict",
			# This also avoids creating a $homedir/trustdb.gpg
			"--trust-model", "always",
			# Avoid trying to open /dev/tty
			"--no-tty",
			# This avoids starting gpg-agent and creating a $homdir/S.gpg-agent and $homedir/private-keys-v1.d/
			"--no-autostart",
			"--no-auto-check-trustdb",
			"--no-default-keyring",
			# Default is $HOME/.gnupg; set this to avoid "gpg: Fatal: /root/.gnupg: directory does not exist!"
			# after it successfully writes to keybox_file.
			"--homedir", homedir,
			"--primary-keyring", keybox_file,
		]
	end

	def package_dependencies(_, _release), do: ["faketime", "gnupg2"]
end

defimpl Inspect, for: Converge.GPGKeybox do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		count = length(u.keys)
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
