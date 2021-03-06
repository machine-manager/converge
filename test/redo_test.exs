alias Gears.FileUtil
alias Converge.{Unit, Runner, UnitError, AfterMeet, Redo, RedoAfterMeet}
alias Converge.TestHelpers.{ConvergeableUnit, TestingContext}

defmodule Converge.Runner.RedoTest do
	use ExUnit.Case, async: true

	test "Redo forces a call to meet if the unit failed to converge last time" do
		FileUtil.rm_f!("/tmp/converge-RedoTest/1")
		ctx = TestingContext.get_context()
		cu  = ConvergeableUnit.new()
		t   = %Redo{
			marker:  "/tmp/converge-RedoTest/1",
			unit:    %AfterMeet{unit: cu, trigger: fn -> raise(UnitError, "from trigger") end},
		}
		assert_raise(
			UnitError, ~r/^from trigger$/,
			fn -> Runner.converge(t, ctx) end
		)
		# Marker file should exist
		assert File.regular?("/tmp/converge-RedoTest/1")
		# Unit should be already converged at this point
		assert Unit.met?(cu, ctx)
		t = %Redo{
			marker: "/tmp/converge-RedoTest/1",
			unit:    %AfterMeet{unit: cu, trigger: fn -> :ok end},
		}
		Runner.converge(t, ctx)
		# Marker file should no longer exist
		assert not File.regular?("/tmp/converge-RedoTest/1")
	end

	test "Redo.met? and Redo.meet with relative path for marker raise UnitError" do
		ctx = TestingContext.get_context()
		u   = %Redo{marker: "relative", unit: ConvergeableUnit.new()}
		assert_raise(UnitError, ~r/not absolute/, fn -> Unit.met?(u, ctx) end)
		assert_raise(UnitError, ~r/not absolute/, fn -> Unit.meet(u, ctx) end)
	end
end


defmodule Converge.Runner.RedoAfterMeetTest do
	use ExUnit.Case, async: true

	test "RedoAfterMeet forces a call to trigger if it raised an exception last time" do
		FileUtil.rm_f!("/tmp/converge-RedoAfterMeet/1")
		ctx = TestingContext.get_context()
		cu  = ConvergeableUnit.new()
		t   = %RedoAfterMeet{
			marker:  "/tmp/converge-RedoAfterMeet/1",
			unit:    cu,
			trigger: fn -> raise(UnitError, "from trigger") end,
		}
		assert_raise(
			UnitError, ~r/^from trigger$/,
			fn -> Runner.converge(t, ctx) end
		)
		# Marker file should exist
		assert File.regular?("/tmp/converge-RedoAfterMeet/1")
		# Unit should be already converged at this point
		assert Unit.met?(cu, ctx)
		t = %RedoAfterMeet{
			marker: "/tmp/converge-RedoAfterMeet/1",
			unit:    cu,
			trigger: fn -> :ok end,
		}
		Runner.converge(t, ctx)
		# Marker file should no longer exist
		assert not File.regular?("/tmp/converge-RedoAfterMeet/1")
	end

	test "RedoAfterMeet.met? and RedoAfterMeet.meet with relative path for marker raise UnitError" do
		ctx = TestingContext.get_context()
		u   = %Redo{marker: "relative", unit: ConvergeableUnit.new()}
		assert_raise(UnitError, ~r/not absolute/, fn -> Unit.met?(u, ctx) end)
		assert_raise(UnitError, ~r/not absolute/, fn -> Unit.meet(u, ctx) end)
	end
end
