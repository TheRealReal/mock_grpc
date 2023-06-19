defmodule MockGRPC do
  @moduledoc """
  To mock gRPC calls in the test suite you must add the following block to your test file

    setup do
      MockGRPC.setup()
    end

  then, use `MockGRPC.expect/2` to validate the calls. The first arg is the request module, followed by a fn that
  takes the mocked fn's arguments and returns your custom result.

  note: must be run async: false for now
  """

  def setup do
    ExUnit.Callbacks.on_exit(fn ->
      verify!()
      clear_state()
    end)

    :ok
  end

  def verify! do
    state = MockGRPC.Server.get_expectations()

    failures =
      Enum.filter(state, fn %{called: called} ->
        called == false
      end)

    if failures != [] do
      formatted_failures =
        Enum.map(failures, fn %{service_module: mod, fun_name: fun} ->
          "Expected to receive gRPC call to #{mod_name(mod)}.Stub.#{fun}() but didn't"
        end)

      raise Enum.join(formatted_failures, "\n")
    end
  end

  defp mod_name(mod), do: mod |> to_string() |> String.replace("Elixir.", "", global: false)

  def expect(grpc_fun, mock_fun) when is_function(grpc_fun) and is_function(mock_fun) do
    case MockGRPC.Util.extract_grpc_fun(grpc_fun) do
      %{service_module: service_module, fun_name: fun_name} ->
        expect(service_module, fun_name, mock_fun)

      _ ->
        raise "Invalid function passed to MockGRPC.expect/2. Expected a stub function capture, e.g.: `&MyService.Stub.fun/2`. Received #{inspect(grpc_fun)}."
    end
  end

  def expect(service_module, fun_name, mock_fun)
      when is_atom(service_module) and is_atom(fun_name) and is_function(mock_fun) do
    MockGRPC.Server.expect(service_module, fun_name, mock_fun)
  end

  def clear_state, do: MockGRPC.Server.clear_state()
end
