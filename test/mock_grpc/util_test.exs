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

  describe "get_test_key/0" do
    test "gets test key from dictionary of the current process" do
      Process.put(MockGRPC, self())
      assert get_test_key() == self()
    end

    test "returns :global when test key is not set" do
      assert get_test_key() == :global
    end

    test "gets correct test key inside Task" do
      parent = self()
      Process.put(MockGRPC, parent)

      Task.async(fn ->
        send(parent, {:test_key_inside_task, get_test_key()})
      end)
      |> Task.await()

      assert_receive {:test_key_inside_task, ^parent}
    end

    test "gets correct test key inside nested Task" do
      parent = self()
      Process.put(MockGRPC, parent)

      Task.async(fn ->
        Task.async(fn ->
          send(parent, {:test_key_inside_nested_task, get_test_key()})
        end)
        |> Task.await()
      end)
      |> Task.await()

      assert_receive {:test_key_inside_nested_task, ^parent}
    end

    test "returns :global when test key cannot be found in $callers" do
      parent = self()

      Task.async(fn ->
        Task.async(fn ->
          send(parent, {:test_key_inside_nested_task, get_test_key()})
        end)
        |> Task.await()
      end)
      |> Task.await()

      assert_receive {:test_key_inside_nested_task, :global}
    end
  end
end
