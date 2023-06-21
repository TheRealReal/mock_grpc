## Simulating unavailable channel

To make `MockGRPC.up/0` and `MockGRPC.down/0` work with ConnGRPC, you can use its `mock` option.

First, add to your test configuration file (e.g. `config/test.exs`):

```elixir
Application.put_env(:demo, :conn_grpc_adapter, MockGRPC.Adapter)

Application.put_env(:demo, :conn_grpc_mock, fn test_pid ->
  MockGRPC.set_context(test_pid)
  GRPC.Stub.connect("dummy", adapter: MockGRPC.Adapter)
end)
```

Then, pass `mock` to your channel configuration.

If you're using `ConnGRPC.Pool`:

```elixir
defmodule DemoPool do
  use ConnGRPC.Pool,
    pool_size: 5,
    channel: [
      address: Application.get_env(:demo, :demo_grpc_address),
      opts: [adapter: Application.get_env(:demo, :conn_grpc_adapter)],
      mock: Application.get_env(:demo, :conn_grpc_mock)
    ]
end
```

If you're using `ConnGRPC.Channel`:

```elixir
defmodule DemoChannel do
  use ConnGRPC.Channel,
    address: Application.get_env(:demo, :demo_grpc_address),
    opts: [adapter: Application.get_env(:demo, :conn_grpc_adapter)],
    mock: Application.get_env(:demo, :conn_grpc_mock),
end
```

### Why this is needed

`ConnGRPC` starts a channel, or a pool of channels, to be reused throughout your app, and these
channels are started as part of your application supervision tree. Because of this global
nature, by default it's not possible to test connection failure in isolation in parallel tests.

Turning the channel down would do it for the entire application, and prevent parallel tests
from testing different scenarios where the channel is up.

To overcome that, `ConnGRPC` allows passing a `mock` function on the channel setup, so that you
can overwrite the channel returned by it. You can then integrate that mock function with
`MockGRPC.set_context/1` and call `GRPC.Stub.connect/2` inside it to return the mocked channel
in an isolated manner.
