defmodule MockGRPC.AdapterTest do
  use ExUnit.Case

  alias TestSupport.{
    GreetService,
    SayHelloRequest,
    SayHelloResponse
  }

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

  describe "receive_data/2" do
    setup do
      test_key = self()
      Process.put(MockGRPC, test_key)
      {:ok, _} = MockGRPC.start_server(test_key)

      on_exit(fn -> MockGRPC.stop_server(test_key) end)

      :ok
    end

    defp build_stream(rpc_name) do
      test_key = self()
      input = %SayHelloRequest{first_name: "John", last_name: "Doe"}

      MockGRPC.Server.expect(test_key, GreetService.Service, :say_hello, fn ^input ->
        {:ok, %SayHelloResponse{message: "Hello John Doe"}}
      end)

      %GRPC.Client.Stream{
        rpc: {rpc_name, SayHelloRequest, SayHelloResponse},
        service_name: GreetService.Service.__meta__(:name),
        payload: %{input: input}
      }
    end

    test "matches expectations with GRPC 0.11 style underscored string rpc names" do
      stream = build_stream("say_hello")

      assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} =
               MockGRPC.Adapter.receive_data(stream, [])
    end

    test "matches expectations with GRPC 1.0 style original rpc names" do
      stream = build_stream(:SayHello)

      assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} =
               MockGRPC.Adapter.receive_data(stream, [])
    end
  end
end
