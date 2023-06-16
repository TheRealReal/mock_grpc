defmodule MockGRPC.Adapter do
  @moduledoc false

  alias GRPC.Client.Stream

  @behaviour GRPC.Client.Adapter

  @impl true
  def connect(channel, _opts) do
    {:ok, channel}
  end

  @impl true
  def disconnect(channel) do
    {:ok, channel}
  end

  @impl true
  def send_request(%Stream{request_mod: request_mod} = stream, content, _opts) do
    input = request_mod.decode(content)
    Stream.put_payload(stream, :input, input)
  end

  @impl true
  def receive_data(
        %Stream{
          rpc: {fun_name, {_, _}, {_, _}},
          service_name: service_name,
          payload: %{input: input}
        },
        _opts
      ) do
    case MockGRPC.Server.call(service_name, fun_name) do
      nil ->
        raise "Received unexpected gRPC call: `#{service_name}/#{fun_name}` with input: #{inspect(input)}"

      %{mock_fun: mock_fun} ->
        mock_fun.(input)
    end
  end

  @impl true
  def send_headers(stream, _opts) do
    stream
  end

  @impl true
  def send_data(stream, _msg, _opts) do
    stream
  end

  @impl true
  def end_stream(stream) do
    stream
  end

  @impl true
  def cancel(_stream) do
    :ok
  end
end
