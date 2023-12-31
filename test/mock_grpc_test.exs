# Make sure we run all tests on both sync and async mode
for async <- [true, false] do
  test_module_name =
    case async do
      true -> MockGRPC.AsyncTest
      false -> MockGRPC.SyncTest
    end

  defmodule test_module_name do
    use ExUnit.Case, async: async

    use MockGRPC

    alias TestSupport.{
      GreetService,
      SayHelloRequest,
      SayHelloResponse
    }

    setup do
      {:ok, channel} = GRPC.Stub.connect("localhost:50051", adapter: MockGRPC.Adapter)
      {:ok, %{channel: channel}}
    end

    describe "expect/2" do
      test "mocks the call", %{channel: channel} do
        MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        response = GreetService.Stub.say_hello(channel, request)

        assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = response
      end

      test "raises when function capture passed is not from a gRPC stub" do
        assert_raise RuntimeError,
                     ~r|Invalid function passed to `MockGRPC.expect/2`|,
                     fn -> MockGRPC.expect(&Enum.map/2, fn _ -> nil end) end
      end
    end

    describe "expect/3" do
      test "mocks the call", %{channel: channel} do
        MockGRPC.expect(GreetService.Service, :say_hello, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        response = GreetService.Stub.say_hello(channel, request)

        assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = response
      end

      test "allows adding multiple mocks to the same function", %{channel: channel} do
        MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
          {:ok, %SayHelloResponse{message: "Hello 1"}}
        end)

        MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
          {:ok, %SayHelloResponse{message: "Hello 2"}}
        end)

        assert {:ok, %SayHelloResponse{message: "Hello 1"}} =
                 GreetService.Stub.say_hello(channel, %SayHelloRequest{
                   first_name: "John",
                   last_name: "Doe"
                 })

        assert {:ok, %SayHelloResponse{message: "Hello 2"}} =
                 GreetService.Stub.say_hello(channel, %SayHelloRequest{
                   first_name: "Richard",
                   last_name: "Roe"
                 })
      end

      test "makes mock available inside tasks created in the current process", %{channel: channel} do
        MockGRPC.expect(GreetService.Service, :say_hello, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        response =
          Task.async(fn ->
            request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
            GreetService.Stub.say_hello(channel, request)
          end)
          |> Task.await()

        assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = response
      end

      test "supports nested task", %{channel: channel} do
        MockGRPC.expect(GreetService.Service, :say_hello, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        response =
          Task.async(fn ->
            Task.async(fn ->
              request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
              GreetService.Stub.say_hello(channel, request)
            end)
            |> Task.await()
          end)
          |> Task.await()

        assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = response
      end

      test "raises when module passed does not use GRPC.Service" do
        assert_raise RuntimeError,
                     ~r|Invalid service module passed to `MockGRPC.expect/3`|,
                     fn -> MockGRPC.expect(Enum, :map, fn _ -> nil end) end
      end
    end

    describe "Verification" do
      test "does not raise when expectation is called", %{channel: channel} do
        MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        GreetService.Stub.say_hello(channel, request)
      end

      @tag capture_log: true
      test "raises when there is no expectation for call received", %{channel: channel} do
        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}

        assert_raise RuntimeError,
                     ~r|Received unexpected gRPC call: `test_support\.GreetService/say_hello` with input: %TestSupport\.SayHelloRequest|,
                     fn -> GreetService.Stub.say_hello(channel, request) end
      end

      @tag capture_log: true
      test "raises when there is no expectation for call received (multiple calls to same fun)",
           %{
             channel: channel
           } do
        MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
          {:ok, %SayHelloResponse{message: "Hello"}}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}

        assert {:ok, %SayHelloResponse{}} = GreetService.Stub.say_hello(channel, request)

        assert_raise RuntimeError,
                     ~r|Received unexpected gRPC call: `test_support\.GreetService/say_hello` with input: %TestSupport\.SayHelloRequest|,
                     fn -> GreetService.Stub.say_hello(channel, request) end
      end

      test "raises when expectation is not called" do
        test_key = Process.get(MockGRPC)

        MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to `test_support\.GreetService/say_hello` but didn't",
                     fn -> MockGRPC.verify!(test_key) end

        # Clear expectations state to prevent the call to `MockGRPC.verify!` on `on_exit`
        # from failing this test case
        MockGRPC.Server.clear_expectations(test_key)
      end

      test "raises when expectation is not called (multiple expectations to same fun)", %{
        channel: channel
      } do
        test_key = Process.get(MockGRPC)

        for _ <- 1..2 do
          MockGRPC.expect(GreetService.Service, :say_hello, fn _ ->
            {:ok, %SayHelloResponse{message: "Hello"}}
          end)
        end

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        assert {:ok, %SayHelloResponse{}} = GreetService.Stub.say_hello(channel, request)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to `test_support\.GreetService/say_hello` but didn't",
                     fn -> MockGRPC.verify!(test_key) end

        # Clear expectations state to prevent the call to `MockGRPC.verify!` on `on_exit`
        # from failing this test case
        MockGRPC.Server.clear_expectations(test_key)
      end
    end

    describe "up/0 and down/0" do
      test "changes return value of GRPC.Stub.connect/2" do
        assert {:ok, %GRPC.Channel{}} =
                 GRPC.Stub.connect("localhost:50051", adapter: MockGRPC.Adapter)

        MockGRPC.down()

        assert {:error, :econnrefused} =
                 GRPC.Stub.connect("localhost:50051", adapter: MockGRPC.Adapter)

        MockGRPC.up()

        assert {:ok, %GRPC.Channel{}} =
                 GRPC.Stub.connect("localhost:50051", adapter: MockGRPC.Adapter)
      end
    end

    describe "set_context/1" do
      test "makes mocks available inside the process", %{channel: channel} do
        parent = self()

        MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} == req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        spawn(fn ->
          MockGRPC.set_context(parent)

          response =
            GreetService.Stub.say_hello(channel, %SayHelloRequest{
              first_name: "John",
              last_name: "Doe"
            })

          send(parent, {:my_process_result, response})
        end)

        assert_receive {:my_process_result, {:ok, %SayHelloResponse{message: "Hello John Doe"}}}
      end

      test "works when nested inside a Task", %{channel: channel} do
        MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} == req
          {:ok, %SayHelloResponse{message: "Hello John Doe"}}
        end)

        Task.async(fn ->
          task_pid = self()

          spawn(fn ->
            MockGRPC.set_context(task_pid)

            response =
              GreetService.Stub.say_hello(channel, %SayHelloRequest{
                first_name: "John",
                last_name: "Doe"
              })

            send(task_pid, {:my_process_result, response})
          end)

          assert_receive {:my_process_result, {:ok, %SayHelloResponse{message: "Hello John Doe"}}}
        end)
        |> Task.await()
      end
    end
  end
end
