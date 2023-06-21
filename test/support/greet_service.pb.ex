defmodule TestSupport.SayHelloRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:first_name, 1, type: :string, json_name: "firstName")
  field(:last_name, 2, type: :string, json_name: "lastName")
end

defmodule TestSupport.SayHelloResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:message, 1, type: :string)
end

defmodule TestSupport.GreetService.Service do
  @moduledoc false
  use GRPC.Service,
    name: "test_support.GreetService",
    protoc_gen_elixir_version: "0.11.0"

  rpc(:SayHello, TestSupport.SayHelloRequest, TestSupport.SayHelloResponse)
end

defmodule TestSupport.GreetService.Stub do
  @moduledoc false
  use GRPC.Stub, service: TestSupport.GreetService.Service
end
