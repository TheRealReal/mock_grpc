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
      TestService,
      HelloWorldRequest,
      HelloWorldResponse
    }

    setup do
      {:ok, channel} = GRPC.Stub.connect("localhost:50020", adapter: MockGRPC.Adapter)
      {:ok, %{channel: channel}}
    end

    describe "expect/2" do
      test "mocks the call", %{channel: channel} do
        MockGRPC.expect(&TestService.Stub.hello_world/2, fn arg ->
          assert %HelloWorldRequest{first_name: "John", last_name: "Doe"} = arg
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
        response = TestService.Stub.hello_world(channel, request)

        assert %HelloWorldResponse{message: "Hello John Doe"} = response
      end
    end

    describe "expect/3" do
      test "mocks the call", %{channel: channel} do
        MockGRPC.expect(TestService, :hello_world, fn arg ->
          assert %HelloWorldRequest{first_name: "John", last_name: "Doe"} = arg
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
        response = TestService.Stub.hello_world(channel, request)

        assert %HelloWorldResponse{message: "Hello John Doe"} = response
      end

      test "allows adding multiple mocks to the same function", %{channel: channel} do
        MockGRPC.expect(TestService, :hello_world, fn _ ->
          %HelloWorldResponse{message: "Hello 1"}
        end)

        MockGRPC.expect(TestService, :hello_world, fn _ ->
          %HelloWorldResponse{message: "Hello 2"}
        end)

        assert %HelloWorldResponse{message: "Hello 1"} =
                 TestService.Stub.hello_world(channel, %HelloWorldRequest{
                   first_name: "John",
                   last_name: "Doe"
                 })

        assert %HelloWorldResponse{message: "Hello 2"} =
                 TestService.Stub.hello_world(channel, %HelloWorldRequest{
                   first_name: "Richard",
                   last_name: "Roe"
                 })
      end

      test "makes mock available inside tasks created in the current process", %{channel: channel} do
        MockGRPC.expect(TestService, :hello_world, fn arg ->
          assert %HelloWorldRequest{first_name: "John", last_name: "Doe"} = arg
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        parent = self()

        Task.async(fn ->
          request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
          response = TestService.Stub.hello_world(channel, request)
          send(parent, {:task_response, response})
        end)

        assert_receive {:task_response, %HelloWorldResponse{message: "Hello John Doe"}}
      end

      test "supports nested task", %{channel: channel} do
        MockGRPC.expect(TestService, :hello_world, fn arg ->
          assert %HelloWorldRequest{first_name: "John", last_name: "Doe"} = arg
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        parent = self()

        Task.async(fn ->
          Task.async(fn ->
            request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
            response = TestService.Stub.hello_world(channel, request)
            send(parent, {:task_response, response})
          end)
        end)

        assert_receive {:task_response, %HelloWorldResponse{message: "Hello John Doe"}}
      end
    end

    describe "Verification" do
      test "does not raise when expectation is called", %{channel: channel} do
        MockGRPC.expect(TestService, :hello_world, fn _ ->
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
        TestService.Stub.hello_world(channel, request)
      end

      @tag capture_log: true
      test "raises when there is no expectation for call received", %{channel: channel} do
        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}

        assert_raise RuntimeError,
                     ~r|Received unexpected gRPC call: `test_support\.TestService/hello_world` with input: %TestSupport\.HelloWorldRequest|,
                     fn -> TestService.Stub.hello_world(channel, request) end
      end

      @tag capture_log: true
      test "raises when there is no expectation for call received (multiple calls to same fun)",
           %{
             channel: channel
           } do
        MockGRPC.expect(TestService, :hello_world, fn _ ->
          %HelloWorldResponse{message: "Hello"}
        end)

        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}

        assert %HelloWorldResponse{} = TestService.Stub.hello_world(channel, request)

        assert_raise RuntimeError,
                     ~r|Received unexpected gRPC call: `test_support\.TestService/hello_world` with input: %TestSupport\.HelloWorldRequest|,
                     fn -> TestService.Stub.hello_world(channel, request) end
      end

      test "raises when expectation is not called" do
        test_key = Process.get(MockGRPC)

        MockGRPC.expect(TestService, :hello_world, fn _ ->
          %HelloWorldResponse{message: "Hello John Doe"}
        end)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to TestSupport.TestService.Stub.hello_world() but didn't",
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
          MockGRPC.expect(TestService, :hello_world, fn _ ->
            %HelloWorldResponse{message: "Hello"}
          end)
        end

        request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
        assert %HelloWorldResponse{} = TestService.Stub.hello_world(channel, request)

        assert_raise RuntimeError,
                     "Expected to receive gRPC call to TestSupport.TestService.Stub.hello_world() but didn't",
                     fn -> MockGRPC.verify!(test_key) end

        # Clear expectations state to prevent the call to `MockGRPC.verify!` on `on_exit`
        # from failing this test case
        MockGRPC.Server.clear_expectations(test_key)
      end
    end
  end
end
