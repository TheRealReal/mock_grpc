defmodule MockGRPCTest do
  use ExUnit.Case

  alias TestSupport.{
    TestService,
    HelloWorldRequest,
    HelloWorldResponse
  }

  setup do
    MockGRPC.clear_state()
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
  end

  describe "Verification" do
    test "does not raise when expectation is called", %{channel: channel} do
      MockGRPC.expect(TestService, :hello_world, fn _ ->
        %HelloWorldResponse{message: "Hello John Doe"}
      end)

      request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
      TestService.Stub.hello_world(channel, request)

      MockGRPC.verify!()
    end

    @tag capture_log: true
    test "raises when there is no expectation for call received", %{channel: channel} do
      request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}

      assert_raise RuntimeError,
                   ~r|Received unexpected gRPC call: `test_support\.TestService/hello_world` with input: %TestSupport\.HelloWorldRequest|,
                   fn -> TestService.Stub.hello_world(channel, request) end
    end

    test "raises when expectation is not called" do
      MockGRPC.expect(TestService, :hello_world, fn _ ->
        %HelloWorldResponse{message: "Hello John Doe"}
      end)

      assert_raise RuntimeError,
                   "Expected to receive gRPC call to TestSupport.TestService.Stub.hello_world() but didn't",
                   fn -> MockGRPC.verify!() end
    end
  end
end
