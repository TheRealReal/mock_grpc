defmodule DemoTest do
  use ExUnit.Case, async: true

  use MockGRPC

  describe "say_hello/2" do
    test "returns greeting" do
      MockGRPC.expect(&Demo.GreetService.Stub.say_hello/2, fn req ->
        assert %Demo.SayHelloRequest{first_name: "John", last_name: "Doe"} == req
        %Demo.SayHelloResponse{message: "Hello John Doe"}
      end)

      assert {:ok, %Demo.SayHelloResponse{message: "Hello John Doe"}} =
               Demo.say_hello("John", "Doe")
    end

    test "returns {:error, reason} when gRPC server is down" do
      MockGRPC.down()
      assert {:error, _} = Demo.say_hello("John", "Doe")
    end
  end
end
