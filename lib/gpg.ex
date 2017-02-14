alias Converge.{Unit, Runner, FilePresent}

defmodule Converge.GPGSimpleKeyring do
	@moduledoc """
	A GPG simple keyring (not GPG2 keybox) file exists at `path` and contains
	just keys `keys` (a list of strings, one armored key per string).  Passes
	`mode`, `immutable`, `user`, and `group` through to `FilePresent`.

	The simple keyring format is used to make the output usable with apt,
	which does not support the GPG2 keybox format:
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
		content = u.keys
			|> Enum.map(&decode_armored_key/1)
			|> Enum.join
		%FilePresent{path: u.path, content: content, mode: u.mode, immutable: u.immutable, user: u.user, group: u.group}
	end

	defp decode_armored_key(key) do
		key
		|> String.split("\n")
		# Skip "-----{BEGIN,END} PGP PUBLIC KEY BLOCK-----", "Version: ", "=checksum"
		|> Enum.filter(&(&1 =~ ~r/^[^ =]+$/))
		|> Enum.join
		|> Base.decode64!
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
