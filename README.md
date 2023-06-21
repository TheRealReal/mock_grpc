![Tests](https://github.com/TheRealReal/mock_grpc/actions/workflows/ci.yml/badge.svg)
[![Contributor Covenant](https://img.shields.io/badge/Contributor%20Covenant-2.1-4baaaa.svg)](CODE_OF_CONDUCT.md)

# MockGRPC

Concurrent mocks for [gRPC Elixir](https://github.com/elixir-grpc/grpc).

## Installation

Add `mock_grpc` to your list of dependencies:

```elixir
def deps do
  [
    {:mock_grpc, "~> 0.1"},

    # You also need to have gRPC Elixir installed
    {:grpc, "~> 0.6"}
  ]
end
```

## How to use

Imagine that you have a module calling a `say_hello` RPC.

```elixir
defmodule Demo do
  def say_hello(name) do
    {:ok, channel} = GRPC.Stub.connect("localhost:50051")
    GreetService.Stub.say_hello(channel, %SayHelloRequest{name: "John Doe"})
  end
end
```

The first step is to change the `connect` code to use an adapter coming from the app environment, so that you can use `MockGRPC` in test mode, and the default adapter in dev and production.

```elixir
{:ok, channel} =
  GRPC.Stub.connect(
    "localhost:50051",
    adapter: Application.get_env(:demo, :grpc_adapter)
  )
```

Or if you're using [`ConnGRPC`](https://github.com/TheRealReal/conn_grpc), add `adapter` to the channel `opts`.

Then, on your `config/test.exs`, set it to `MockGRPC.Adapter`:

```elixir
Application.put_env(:demo, :grpc_adapter, MockGRPC.Adapter)
```


Now it's time to write your test. To enable mocks, add `use MockGRPC` to your test, and call `MockGRPC.expect/2` or `MockGRPC.expect/3` to set expectations.

```elixir
defmodule DemoTest do
  use ExUnit.Case, async: true

  use MockGRPC

  test "say_hello/1" do
    MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
      assert %SayHelloRequest{name: "John Doe"} == req
      {:ok, %SayHelloResponse{message: "Hello John Doe"}}
    end)

    assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = Demo.say_hello("John Doe")
  end
end
```

For more info, see [`MockGRPC` on Hexdocs](https://hexdocs.pm/mock_grpc/).

## Code of Conduct

This project uses Contributor Covenant version 2.1. Check [CODE_OF_CONDUCT.md](/CODE_OF_CONDUCT.md) file for more information.

## License

MockGRPC source code is released under Apache License 2.0.

Check [NOTICE](/NOTICE) and [LICENSE](/LICENSE) files for more information.
