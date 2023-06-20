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
