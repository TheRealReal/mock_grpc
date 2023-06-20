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
        MockGRPC.expect(&GreetService.Stub.say_hello/2, fn arg ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = arg
          %SayHelloResponse{message: "Hello John Doe"}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        response = GreetService.Stub.say_hello(channel, request)

        assert %SayHelloResponse{message: "Hello John Doe"} = response
      end
    end

    describe "expect/3" do
      test "mocks the call", %{channel: channel} do
        MockGRPC.expect(GreetService, :say_hello, fn arg ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = arg
          %SayHelloResponse{message: "Hello John Doe"}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        response = GreetService.Stub.say_hello(channel, request)

        assert %SayHelloResponse{message: "Hello John Doe"} = response
      end

      test "allows adding multiple mocks to the same function", %{channel: channel} do
        MockGRPC.expect(GreetService, :say_hello, fn _ ->
          %SayHelloResponse{message: "Hello 1"}
        end)

        MockGRPC.expect(GreetService, :say_hello, fn _ ->
          %SayHelloResponse{message: "Hello 2"}
        end)

        assert %SayHelloResponse{message: "Hello 1"} =
                 GreetService.Stub.say_hello(channel, %SayHelloRequest{
                   first_name: "John",
                   last_name: "Doe"
                 })

        assert %SayHelloResponse{message: "Hello 2"} =
                 GreetService.Stub.say_hello(channel, %SayHelloRequest{
                   first_name: "Richard",
                   last_name: "Roe"
                 })
      end

      test "makes mock available inside tasks created in the current process", %{channel: channel} do
        MockGRPC.expect(GreetService, :say_hello, fn arg ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = arg
          %SayHelloResponse{message: "Hello John Doe"}
        end)

        response =
          Task.async(fn ->
            request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
            GreetService.Stub.say_hello(channel, request)
          end)
          |> Task.await()

        assert %SayHelloResponse{message: "Hello John Doe"} = response
      end

      test "supports nested task", %{channel: channel} do
        MockGRPC.expect(GreetService, :say_hello, fn arg ->
          assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = arg
          %SayHelloResponse{message: "Hello John Doe"}
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

        assert %SayHelloResponse{message: "Hello John Doe"} = response
      end
    end

    describe "Verification" do
      test "does not raise when expectation is called", %{channel: channel} do
        MockGRPC.expect(GreetService, :say_hello, fn _ ->
          %SayHelloResponse{message: "Hello John Doe"}
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
        MockGRPC.expect(GreetService, :say_hello, fn _ ->
          %SayHelloResponse{message: "Hello"}
        end)

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}

        assert %SayHelloResponse{} = GreetService.Stub.say_hello(channel, request)

        assert_raise RuntimeError,
                     ~r|Received unexpected gRPC call: `test_support\.GreetService/say_hello` with input: %TestSupport\.SayHelloRequest|,
                     fn -> GreetService.Stub.say_hello(channel, request) end
      end

      test "raises when expectation is not called" do
        test_key = Process.get(MockGRPC)

        MockGRPC.expect(GreetService, :say_hello, fn _ ->
          %SayHelloResponse{message: "Hello John Doe"}
        end)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to TestSupport.GreetService.Stub.say_hello() but didn't",
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
          MockGRPC.expect(GreetService, :say_hello, fn _ ->
            %SayHelloResponse{message: "Hello"}
          end)
        end

        request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
        assert %SayHelloResponse{} = GreetService.Stub.say_hello(channel, request)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to TestSupport.GreetService.Stub.say_hello() but didn't",
                     fn -> MockGRPC.verify!(test_key) end

        # Clear expectations state to prevent the call to `MockGRPC.verify!` on `on_exit`
        # from failing this test case
        MockGRPC.Server.clear_expectations(test_key)
      end
    end
  end
end
