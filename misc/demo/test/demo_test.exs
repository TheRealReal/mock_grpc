defmodule DemoTest do
  use ExUnit.Case

  setup do
    MockGRPC.setup()
  end

  test "say_hello/2" do
    MockGRPC.expect(Demo.HelloWorldRequest, fn req ->
      assert %Demo.HelloWorldRequest{first_name: "John", last_name: "Doe"} == req
      %Demo.HelloWorldResponse{message: "Hello John Doe"}
    end)

    assert {:ok, %Demo.HelloWorldResponse{message: "Hello John Doe"}} =
             Demo.say_hello("John", "Doe")
  end
end
