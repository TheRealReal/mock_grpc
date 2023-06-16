defmodule MockGRPC.Adapter do
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
  def receive_data(%Stream{request_mod: request_mod, payload: %{input: input}}, _opts) do
    case MockGRPC.Server.call(request_mod) do
      nil -> raise "received unexpected gRPC call: #{request_mod} with input: #{inspect(input)}"
      %{fun: fun} -> fun.(input)
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
