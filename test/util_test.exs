alias Converge.Util

defmodule Converge.UtilTest do
	use ExUnit.Case, async: true

	test "get_meminfo" do
		info = Util.get_meminfo()

		assert is_integer(info["MemTotal"])
		# Assume the machine running these tests has >= 32MB RAM
		assert info["MemTotal"] > 32 * 1024 * 1024

		assert is_integer(info["MemFree"])
		assert info["MemFree"] < info["MemTotal"]

		assert is_integer(info["HugePages_Total"])
	end

	test "installed?" do
		assert Util.installed?("procps")      == true
		assert Util.installed?("not-a-thing") == false
	end

	test "get_country" do
		assert is_binary(Util.get_country())
		assert Util.get_country() =~ ~r/^[a-z]{2}$/
	end

	test "get_hostname" do
		assert is_binary(Util.get_hostname())
	end
end
