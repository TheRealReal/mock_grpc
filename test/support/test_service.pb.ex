defmodule TestSupport.HelloWorldRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :first_name, 1, type: :string, json_name: "firstName"
  field :last_name, 2, type: :string, json_name: "lastName"
end

defmodule TestSupport.HelloWorldResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field :message, 1, type: :string
end

defmodule TestSupport.TestService do
  @moduledoc false
  use GRPC.Service,
    name: "test_support.TestService",
    protoc_gen_elixir_version: "0.11.0"

  rpc :HelloWorld, TestSupport.HelloWorldRequest, TestSupport.HelloWorldResponse
end

defmodule TestSupport.TestService.Stub do
  @moduledoc false
  use GRPC.Stub, service: TestSupport.TestService
end
