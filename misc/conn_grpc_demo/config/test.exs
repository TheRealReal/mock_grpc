import Config

Application.put_env(:demo, :grpc_adapter, MockGRPC.Adapter)

Application.put_env(:demo, :conn_grpc_mock, fn test_pid ->
  MockGRPC.set_context(test_pid)
  GRPC.Stub.connect("dummy", adapter: MockGRPC.Adapter)
end)
