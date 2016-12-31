alias Gears.FileUtil
alias Converge.{Unit, Runner, FilePresent}

defmodule Converge.GPGSimpleKeyring do
	@moduledoc """
	A GPG simple keyring (not GPG2 keybox) file exists at `path` and contains
	just keys `keys` (a list of strings containing an armored key).  Passes
	`mode`, `immutable`, `user`, and `group` through to `FilePresent`.
	"""
	@enforce_keys [:path, :keys, :mode]
	defstruct path: nil, keys: [], mode: nil, immutable: false, user: "root", group: "root"
end

defimpl Unit, for: Converge.GPGSimpleKeyring do
	def met?(u, ctx) do
		Runner.met?(make_unit(u), ctx)
	end

	def meet(u, ctx) do
		Runner.converge(make_unit(u), ctx)
	end

	defp make_unit(u) do
		temporary_keybox_file = make_keybox_file(u.keys)
		content = try do
			get_simple_keyring(temporary_keybox_file)
		after
			FileUtil.rm_f!(temporary_keybox_file)
		end
		%FilePresent{path: u.path, content: content, mode: u.mode, immutable: u.immutable, user: u.user, group: u.group}
	end

	# Takes a list of keys, returns the path to a temporary file containing
	# a GPG2 keybox with those keys.
	defp make_keybox_file(keys) do
		keybox_file = FileUtil.temp_path("converge-gpg2-keybox")
		# Create an empty keybox, because `keys` may be empty
		create_empty_keybox(keybox_file)
		for key <- keys do
			key_file = FileUtil.temp_path("converge-gpg2-key")
			File.write!(key_file, key)
			{"", 0} = System.cmd("gpg2", get_gpg_opts(keybox_file) ++ [
				"--import", key_file,
			])
			FileUtil.rm_f!(key_file)
		end
		keybox_file
	end

	defp create_empty_keybox(keybox_file) do
		{"gpg: no valid OpenPGP data found.\n", 2} = System.cmd("gpg2", get_gpg_opts(keybox_file) ++ [
			"--import", "/dev/null"
		], stderr_to_stdout: true)
	end

	# Takes a path `keybox_file` (keybox or simple keyring), returns a string
	# containing a simple keyring export of the keyring.
	defp get_simple_keyring(keybox_file) do
		{out, 0} = System.cmd("gpg2", get_gpg_opts(keybox_file) ++ [
			"--export",
		], stderr_to_stdout: true)
		case out do
			"gpg: WARNING: nothing exported\n" -> ""
			other                              -> other
		end
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
