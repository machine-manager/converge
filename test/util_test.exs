alias Converge.{Util, TagValueError}

defmodule Converge.UtilTest do
	use ExUnit.Case, async: true
	require Util

	test "get_meminfo" do
		info = Util.get_meminfo()

		assert is_integer(info["MemTotal"])
		# Assume the machine running these tests has >= 32MB RAM
		assert info["MemTotal"] > 32 * 1024 * 1024

		assert is_integer(info["MemFree"])
		assert info["MemFree"] < info["MemTotal"]

		assert is_integer(info["HugePages_Total"])
	end

	test "get_cpuinfo" do
		info = Util.get_cpuinfo()

		assert is_integer(info.cores)
		assert is_integer(info.threads)
		assert is_integer(info.sockets)
		assert info.threads >= info.cores
		assert info.cores   >= info.sockets
		assert is_binary(info.architecture)
		assert is_binary(info.model_name)
		assert is_binary(info.vendor_id)
		assert info.hypervisor_vendor == nil or is_binary(info.hypervisor_vendor)
		assert is_integer(info.stepping)
		assert is_float(info.cpu_mhz)
		assert info.cpu_max_mhz == nil or is_float(info.cpu_max_mhz)
		assert info.cpu_min_mhz == nil or is_float(info.cpu_min_mhz)
		assert is_list(info.flags)
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

	test "get_ip" do
		ip = Util.get_ip()
		assert is_binary(ip)
		assert ip =~ ~r/^[\d\.]+$/
	end

	test "tag_value!" do
		assert_raise TagValueError, ~r/^No tag with prefix /, fn -> Util.tag_value!([], "") end
		assert_raise TagValueError, ~r/^No tag with prefix /, fn -> Util.tag_value!([], "a") end
		assert_raise TagValueError, ~r/^No tag with prefix /, fn -> Util.tag_value!(["a"], "a") end
		assert Util.tag_value!(["a:x"], "a")         == "x"
		assert_raise TagValueError, ~r/^Multiple tags /, fn -> Util.tag_value!(["a:x", "a:yy"], "a") end
		assert Util.tag_value!(["ab:x", "a:y"], "a") == "y"
	end

	test "tag_value" do
		assert Util.tag_value([], "")               == nil
		assert Util.tag_value([], "a")              == nil
		assert Util.tag_value(["a"], "a")           == nil
		assert Util.tag_value(["a:x"], "a")         == "x"
		assert_raise TagValueError, ~r/^Multiple tags /, fn -> Util.tag_value(["a:x", "a:yy"], "a") end
		assert Util.tag_value(["ab:x", "a:y"], "a") == "y"
	end

	test "tag_values" do
		assert Util.tag_values([], "")               == []
		assert Util.tag_values([], "a")              == []
		assert Util.tag_values(["a"], "a")           == []
		assert Util.tag_values(["a:x"], "a")         == ["x"]
		assert Util.tag_values(["a:x", "a:yy"], "a") == ["x", "yy"]
		assert Util.tag_values(["ab:x", "a:y"], "a") == ["y"]
	end

	test "marker" do
		assert Util.marker("demo") == "/tmp/converge/markers/Elixir.Converge.UtilTest/demo"
	end
end
