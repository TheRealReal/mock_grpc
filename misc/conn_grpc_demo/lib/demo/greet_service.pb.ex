defmodule Demo.SayHelloRequest do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:first_name, 1, type: :string, json_name: "firstName")
  field(:last_name, 2, type: :string, json_name: "lastName")
end

defmodule Demo.SayHelloResponse do
  @moduledoc false
  use Protobuf, protoc_gen_elixir_version: "0.11.0", syntax: :proto3

  field(:message, 1, type: :string)
end

defmodule Demo.GreetService do
  @moduledoc false
  use GRPC.Service,
    name: "demo.GreetService",
    protoc_gen_elixir_version: "0.11.0"

  rpc(:SayHello, Demo.SayHelloRequest, Demo.SayHelloResponse)
end

defmodule Demo.GreetService.Stub do
  @moduledoc false
  use GRPC.Stub, service: Demo.GreetService
end
