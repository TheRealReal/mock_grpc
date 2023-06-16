import Config

Application.put_env(:demo, :grpc_adapter, MockGRPC.Adapter)
