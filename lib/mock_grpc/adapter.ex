defmodule MockGRPC.Adapter do
  @moduledoc false

  alias GRPC.Client.Stream

  @behaviour GRPC.Client.Adapter

  @impl true
  def connect(channel, _opts) do
    test_key = MockGRPC.Util.get_test_key()
    # GRPC 0.11.x expects adapter_payload.conn_pid to be set by the adapter.
    # We use self() as a dummy pid since MockGRPC intercepts requests at the
    # receive_data/2 level, not at the connection level.
    case check_server_status(test_key, channel) do
      {:ok, channel} -> {:ok, %{channel | adapter_payload: %{conn_pid: self()}}}
      error -> error
    end
  end

  defp check_server_status(test_key, channel) do
    if MockGRPC.Server.alive?(test_key) do
      case MockGRPC.Server.get_status(test_key) do
        :up -> {:ok, channel}
        :down -> {:error, :econnrefused}
      end
    else
      {:ok, channel}
    end
  end

  @impl true
  def disconnect(channel) do
    {:ok, channel}
  end

  @impl true
  def send_request(%Stream{request_mod: request_mod} = stream, content, _opts) do
    input = content |> to_binary() |> request_mod.decode()
    Stream.put_payload(stream, :input, input)
  end

  defp to_binary(content) when is_binary(content), do: content
  defp to_binary(content) when is_list(content), do: IO.iodata_to_binary(content)

  @impl true
  def receive_data(
        %Stream{rpc: rpc, service_name: service_name, payload: %{input: input}},
        _opts
      ) do
    test_key = MockGRPC.Util.get_test_key()
    fun_name = elem(rpc, 0)

    unless MockGRPC.Server.alive?(test_key) do
      raise """
      Received gRPC call `#{service_name}/#{fun_name}` without MockGRPC being set up.
      Please make sure you've added `use MockGRPC` to your test file.
      """
    end

    case MockGRPC.Server.call(test_key, service_name, fun_name) do
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
