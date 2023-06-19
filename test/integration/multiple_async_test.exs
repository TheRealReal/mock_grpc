# This file generates multiple ExUnit test modules to execute tests in parallel.
# Half are sync and half are async.
# The goal is to verify if mock isolation is working properly.
for i <- 1..20 do
  defmodule String.to_atom("Elixir.MockGRPC.Integration.MultipleAsync#{i}Test") do
    use ExUnit.Case, async: i <= 10

    use MockGRPC

    alias TestSupport.{
      TestService,
      HelloWorldRequest,
      HelloWorldResponse
    }

    test "async test" do
      MockGRPC.expect(&TestService.Stub.hello_world/2, fn arg ->
        assert %HelloWorldRequest{first_name: "John", last_name: "Doe"} = arg
        %HelloWorldResponse{message: "Hello #{unquote(i)}"}
      end)

      # Allow for race conditions if code is not implemented properly
      :timer.sleep(Enum.random(0..500))

      {:ok, channel} = GRPC.Stub.connect("localhost:50020", adapter: MockGRPC.Adapter)
      request = %HelloWorldRequest{first_name: "John", last_name: "Doe"}
      response = TestService.Stub.hello_world(channel, request)

      expected_msg = "Hello #{unquote(i)}"
      assert %HelloWorldResponse{message: ^expected_msg} = response
    end
  end
end
