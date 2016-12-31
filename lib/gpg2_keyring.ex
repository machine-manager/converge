alias Gears.FileUtil
alias Converge.{Unit, Runner, FilePresent}

defmodule Converge.GPG2Keyring do
	@moduledoc """
	A GPG2 keyring file `path` exists and contains just keys `keys` (a list of
	strings with armored keys).  Passes `mode`, `immutable`, `user`, and `group`
	through to `FilePresent`.
	"""
	@enforce_keys [:path, :keys, :mode]
	defstruct path: nil, keys: [], mode: nil, immutable: false, user: "root", group: "root"
end

# This is implemented in a roundabout way because gpg2 --import doesn't produce
# identical keyrings, even when given a --faked-system-time.  Instead of creating
# a new temporary keyring and checking if it's byte-identical to the existing
# keyring, we use gpg2 --with-colons to compare the list of the keys in the current
# and desired keyrings.
defimpl Unit, for: Converge.GPG2Keyring do
	def met?(u, ctx) do
		current_key_listing = get_key_listing_or_nil(u.path)
		case current_key_listing do
			nil -> false
			_   ->
				# Hopefully the file hasn't changed since the call to get_key_listing_or_nil
				existing_content       = File.read!(u.path)
				temporary_keyring_file = make_keyring_file(u.keys)
				desired_key_listing    = get_key_listing_or_nil(temporary_keyring_file)
				FileUtil.rm_f!(temporary_keyring_file)
				# This is kind of gross.  FilePresent needs a `content` string, so
				# give it the existing content, but only if the key listings match.
				current_key_listing == desired_key_listing and \
					Runner.met?(make_unit(u, existing_content), ctx)
		end
	end

	def meet(u, ctx) do
		temporary_keyring_file = make_keyring_file(u.keys)
		new_content            = File.read!(temporary_keyring_file)
		FileUtil.rm_f!(temporary_keyring_file)
		Runner.converge(make_unit(u, new_content), ctx)
	end

	defp make_unit(u, content) do
		%FilePresent{path: u.path, content: content, mode: u.mode, immutable: u.immutable, user: u.user, group: u.group}
	end

	# Takes a list of keys, returns the path to a temporary file containing
	# a GPG2 keyring with those keys.
	defp make_keyring_file(keys) do
		keyring_file = FileUtil.temp_path("converge-gpg2-keyring")
		# Create an empty keyring, in case keys is empty
		create_empty_keyring(keyring_file)
		for key <- keys do
			key_file = FileUtil.temp_path("converge-gpg2-key")
			File.write!(key_file, key)
			{"", 0} = System.cmd("gpg2", get_gpg_opts(keyring_file) ++ [
				"--import", key_file,
			])
			FileUtil.rm_f!(key_file)
		end
		keyring_file
	end

	defp create_empty_keyring(keyring_file) do
		{"gpg: no valid OpenPGP data found.\n", 2} = System.cmd("gpg2", get_gpg_opts(keyring_file) ++ [
			"--import", "/dev/null"
		], stderr_to_stdout: true)
	end

	# Takes a path `keyring_file`, returns a string containing a machine-parseable
	# key listing (gpg2's "--with-colons" format) of keys in that file, or `nil`
	# if the file does not exist.
	defp get_key_listing_or_nil(keyring_file) do
		case File.regular?(keyring_file) do
			true  -> get_key_listing(keyring_file)
			false -> nil
		end
	end

	defp get_key_listing(keyring_file) do
		{out, 0} = System.cmd("gpg2", get_gpg_opts(keyring_file) ++ [
			"--with-colons",
			"--with-secret",
			"--fingerprint",
		])
		out
	end

	defp get_gpg_opts(keyring_file) do
		[
			"--quiet",
			"--no-options",
			"--no-default-keyring",
			"--primary-keyring", keyring_file,
		]
	end
end

defimpl Inspect, for: Converge.GPG2Keyring do
	import Inspect.Algebra
	import Gears.StringUtil, only: [counted_noun: 3]

	def inspect(u, opts) do
		count = u.keys |> length
		concat([
			color("%Converge.GPG2Keyring{", :map, opts),
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
