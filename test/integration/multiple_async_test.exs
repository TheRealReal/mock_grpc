# This file generates multiple ExUnit test modules to execute tests in parallel.
# Half are sync and half are async.
# The goal is to verify if mock isolation is working properly.
for i <- 1..20 do
  defmodule String.to_atom("Elixir.MockGRPC.Integration.MultipleAsync#{i}Test") do
    use ExUnit.Case, async: i <= 10

    use MockGRPC

    alias TestSupport.{
      GreetService,
      SayHelloRequest,
      SayHelloResponse
    }

    test "async test" do
      MockGRPC.expect(&GreetService.Stub.say_hello/2, fn arg ->
        assert %SayHelloRequest{first_name: "John", last_name: "Doe"} = arg
        %SayHelloResponse{message: "Hello #{unquote(i)}"}
      end)

      # Allow for race conditions if code is not implemented properly
      :timer.sleep(Enum.random(0..500))

      {:ok, channel} = GRPC.Stub.connect("localhost:50051", adapter: MockGRPC.Adapter)
      request = %SayHelloRequest{first_name: "John", last_name: "Doe"}
      response = GreetService.Stub.say_hello(channel, request)

      expected_msg = "Hello #{unquote(i)}"
      assert %SayHelloResponse{message: ^expected_msg} = response
    end
  end
end
