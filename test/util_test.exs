defmodule Converge.UtilTest do
	use ExUnit.Case, async: true

	test "get_meminfo works" do
		info = Converge.Util.get_meminfo()

		assert is_integer(info["MemTotal"])
		# These tests will hopefully never run on a machine with < 32MB RAM
		assert info["MemTotal"] > 32 * 1024 * 1024

		assert is_integer(info["MemFree"])
		assert info["MemFree"] < info["MemTotal"]

		assert is_integer(info["HugePages_Total"])
	end
end
