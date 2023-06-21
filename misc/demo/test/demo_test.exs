defmodule DemoTest do
  use ExUnit.Case, async: true

  use MockGRPC

  test "say_hello/2" do
    MockGRPC.expect(&Demo.GreetService.Stub.say_hello/2, fn req ->
      assert %Demo.SayHelloRequest{first_name: "John", last_name: "Doe"} == req
      {:ok, %Demo.SayHelloResponse{message: "Hello John Doe"}}
    end)

    assert {:ok, %Demo.SayHelloResponse{message: "Hello John Doe"}} =
             Demo.say_hello("John", "Doe")
  end
end
