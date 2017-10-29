alias Gears.FileUtil
alias Converge.{GPGSimpleKeyring, GPGKeybox, Runner}
alias Converge.TestHelpers.TestingContext

defmodule Converge.GPGSimpleKeyringTest do
	use ExUnit.Case, async: true

	@wine_ppa_key             File.read!(Path.join(__DIR__, "gpg_keys/wina_ppa_key.gpg"))
	@graphics_drivers_ppa_key File.read!(Path.join(__DIR__, "gpg_keys/graphics_drivers_ppa_key.gpg"))

	test "empty keyring" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keyring with one key" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [@wine_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keyring with two keys" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGSimpleKeyring{path: p, keys: [@wine_ppa_key, @graphics_drivers_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end
end

defmodule Converge.GPGKeyboxTest do
	use ExUnit.Case, async: true

	@wine_ppa_key             File.read!(Path.join(__DIR__, "gpg_keys/wina_ppa_key.gpg"))
	@graphics_drivers_ppa_key File.read!(Path.join(__DIR__, "gpg_keys/graphics_drivers_ppa_key.gpg"))

	test "empty keybox" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGKeybox{path: p, keys: [], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keybox with one key" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGKeybox{path: p, keys: [@wine_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end

	test "keybox with two keys" do
		p = FileUtil.temp_path("converge-gpg-test")
		u = %GPGKeybox{path: p, keys: [@wine_ppa_key, @graphics_drivers_ppa_key], mode: 0o644}
		Runner.converge(u, TestingContext.get_context())
	end
end
