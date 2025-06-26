defmodule MockGRPC.AdapterTest do
  use ExUnit.Case

  describe "send_request/3" do
    test "works with binary (elixir-grpc < 0.10.0)" do
      stream = %GRPC.Client.Stream{request_mod: TestSupport.SayHelloRequest}
      struct = %TestSupport.SayHelloRequest{first_name: "John", last_name: "Doe"}
      content = Protobuf.Encoder.encode(struct)
      assert MockGRPC.Adapter.send_request(stream, content, []).payload.input == struct
    end

    test "works with iodata (elixir-grpc >= 0.10.0)" do
      stream = %GRPC.Client.Stream{request_mod: TestSupport.SayHelloRequest}
      struct = %TestSupport.SayHelloRequest{first_name: "John", last_name: "Doe"}
      content = Protobuf.Encoder.encode_to_iodata(struct)
      assert MockGRPC.Adapter.send_request(stream, content, []).payload.input == struct
    end
  end
end
