defmodule MockGRPC.UtilTest do
  use ExUnit.Case, async: true

  import MockGRPC.Util

  describe "extract_grpc_fun/1" do
    test "extracts data from function capture" do
      result = extract_grpc_fun(&TestSupport.TestService.Stub.hello_world/2)

      assert result == %{
               service_module: TestSupport.TestService,
               fun_name: :hello_world
             }
    end

    test "returns nil for local functions" do
      assert extract_grpc_fun(fn -> :ok end) == nil
    end

    test "returns nil for non-stub modules" do
      assert extract_grpc_fun(&Enum.map/2) == nil
    end
  end
end
