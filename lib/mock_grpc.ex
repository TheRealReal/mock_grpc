defmodule MockGRPC do
  @moduledoc """
  MockGRPC is a library for defining concurrent client mocks for [gRPC Elixir](https://github.com/elixir-grpc/grpc).

  It works by implementing a [client adapter](https://hexdocs.pm/grpc/GRPC.Client.Adapter.html)
  that intercepts requests using the mocks you defined, and performing expectations on them.

  ### Usage

  Imagine that you have a module calling a `hello` RPC.

      defmodule Demo do
        def say_hello(name) do
          {:ok, channel} = GRPC.Stub.connect("localhost:50020")
          TestService.Stub.hello(channel, %HelloWorldRequest{name: "John Doe"})
        end
      end

  The first step is to change the `connect` code to use an adapter coming from the app environment, so that
  you can use `MockGRPC` in test mode, and the default adapter in dev and production.

      {:ok, channel} = GRPC.Stub.connect("localhost:50020", adapter: Application.get_env(:demo, :grpc_adapter))

  Then, on your `config/test.exs`, set it to `MockGRPC.Adapter`:

      Application.put_env(:demo, :grpc_adapter, MockGRPC.Adapter)

  Now it's time to write your test.

  To enable mocks, add `use MockGRPC` to your test, and call `MockGRPC.expect/2` or `MockGRPC.expect/3`
  to set expectations.

      defmodule DemoTest do
        use ExUnit.Case, async: true

        use MockGRPC

        test "say_hello/1" do
          MockGRPC.expect(&TestService.Stub.hello_world/2, fn req ->
            assert %HelloWorldRequest{name: "John Doe"} == req
            %HelloWorldResponse{message: "Hello John Doe"}
          end)

          assert {:ok, %HelloWorldResponse{message: "Hello John Doe"}} = Demo.say_hello("John Doe")
        end
      end
  """

  def setup(context) do
    test_key = if context.async, do: self(), else: :global
    Process.put({MockGRPC, :test_key}, test_key)

    start_server(test_key)

    # `on_exit` runs in a different process than the test, with its own process
    # dictionary, so we need to manually pass `test_key` over to the function
    # calls inside it.
    ExUnit.Callbacks.on_exit(fn ->
      verify!(test_key)
      stop_server(test_key)
    end)

    :ok
  end

  def expect(grpc_fun, mock_fun) when is_function(grpc_fun) and is_function(mock_fun) do
    case MockGRPC.Util.extract_grpc_fun(grpc_fun) do
      %{service_module: service_module, fun_name: fun_name} ->
        expect(service_module, fun_name, mock_fun)

      _ ->
        raise """
        Invalid function passed to MockGRPC.expect/2.
        Expected a stub function capture, e.g.: `&MyService.Stub.fun/2`. Received #{inspect(grpc_fun)}.
        """
    end
  end

  def expect(service_module, fun_name, mock_fun)
      when is_atom(service_module) and is_atom(fun_name) and is_function(mock_fun) do
    test_key = Process.get({MockGRPC, :test_key})

    if test_key == nil do
      raise """
      MockGRPC.expect called without MockGRPC being set up.
      Please make sure you've added `use MockGRPC` to your test file.
      """
    end

    MockGRPC.Server.expect(test_key, service_module, fun_name, mock_fun)
  end

  @doc false
  def start_server(test_key) do
    DynamicSupervisor.start_child(
      MockGRPC.DynamicSupervisor,
      {MockGRPC.Server, test_key: test_key}
    )
  end

  @doc false
  def stop_server(test_key) do
    [{pid, _}] = Registry.lookup(MockGRPC.Registry, test_key)
    DynamicSupervisor.terminate_child(MockGRPC.DynamicSupervisor, pid)
  end

  @doc false
  def verify!(test_key) do
    remaining_expectations = MockGRPC.Server.get_expectations(test_key)

    if remaining_expectations != [] do
      formatted_failures =
        Enum.map(remaining_expectations, fn %{service_module: mod, fun_name: fun} ->
          "Expected to receive gRPC call to #{mod_name(mod)}.Stub.#{fun}() but didn't"
        end)

      raise Enum.join(formatted_failures, "\n")
    end
  end

  defp mod_name(mod), do: mod |> to_string() |> String.replace("Elixir.", "", global: false)

  defmacro __using__(opts \\ []) do
    quote do
      if Keyword.get(unquote(opts), :setup, true) do
        setup context do
          MockGRPC.setup(context)
        end
      end
    end
  end
end
