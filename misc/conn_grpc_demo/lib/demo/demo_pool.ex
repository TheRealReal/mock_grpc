defmodule Demo.DemoPool do
  use ConnGRPC.Pool,
    pool_size: 5,
    channel: [
      address: Application.get_env(:demo, :grpc_address),
      opts: [adapter: Application.get_env(:demo, :grpc_adapter)],
      mock: Application.get_env(:demo, :conn_grpc_mock)
    ]
end
