defmodule MockGRPC.UtilTest do
  use ExUnit.Case, async: true

  import MockGRPC.Util

  describe "extract_grpc_fun/1" do
    test "extracts data from function capture" do
      result = extract_grpc_fun(&TestSupport.GreetService.Stub.say_hello/2)

      assert result == %{
               service_module: TestSupport.GreetService.Service,
               fun_name: :say_hello
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

      result = Task.async(fn -> get_test_key() end) |> Task.await()
      assert result == parent
    end

    test "gets correct test key inside nested Task" do
      parent = self()
      Process.put(MockGRPC, parent)

      result =
        Task.async(fn ->
          Task.async(fn -> get_test_key() end) |> Task.await()
        end)
        |> Task.await()

      assert result == parent
    end

    test "returns :global when test key cannot be found in $callers" do
      result =
        Task.async(fn ->
          Task.async(fn -> get_test_key() end) |> Task.await()
        end)
        |> Task.await()

      assert result == :global
    end
  end

  describe "get_test_key/1" do
    test "gets test key from dictionary of the process passed" do
      Process.put(MockGRPC, self())

      parent = self()

      spawn(fn ->
        assert get_test_key(parent) == parent
        send(parent, :done)
      end)

      assert_receive :done
    end

    test "returns :global when pid passed doesn't have a test key" do
      parent = self()

      spawn(fn ->
        assert get_test_key(parent) == :global
        send(parent, :done)
      end)

      assert_receive :done
    end

    test "gets correct test key inside Task" do
      Process.put(MockGRPC, self())

      parent = self()

      Task.async(fn ->
        task_pid = self()

        spawn(fn ->
          assert get_test_key(task_pid) == parent
          send(task_pid, :done)
        end)

        assert_receive :done
      end)
      |> Task.await()
    end

    test "returns :global when test key cannot be found in $callers" do
      Task.async(fn ->
        task_pid = self()

        spawn(fn ->
          assert get_test_key(task_pid) == :global
          send(task_pid, :done)
        end)

        assert_receive :done
      end)
      |> Task.await()
    end
  end
end
