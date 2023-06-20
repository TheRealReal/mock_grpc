defmodule MockGRPC do
  @moduledoc """
  MockGRPC is a library for defining concurrent client mocks for [gRPC Elixir](https://github.com/elixir-grpc/grpc).

  It works by implementing a [client adapter](https://hexdocs.pm/grpc/GRPC.Client.Adapter.html)
  that intercepts requests using the mocks you defined, and performing expectations on them.

  ### Usage

  Imagine that you have a module calling a `say_hello` RPC.

      defmodule Demo do
        def say_hello(name) do
          {:ok, channel} = GRPC.Stub.connect("localhost:50051")
          GreetService.Stub.say_hello(channel, %SayHelloRequest{name: "John Doe"})
        end
      end

  The first step is to change the `connect` code to use an adapter coming from the app environment, so that
  you can use `MockGRPC` in test mode, and the default adapter in dev and production.

      {:ok, channel} =
        GRPC.Stub.connect(
          "localhost:50051",
          adapter: Application.get_env(:demo, :grpc_adapter)
        )

  Or if you're using [`ConnGRPC`](https://github.com/TheRealReal/conn_grpc), add `adapter` to the channel `opts`.

  Then, on your `config/test.exs`, set it to `MockGRPC.Adapter`:

      Application.put_env(:demo, :grpc_adapter, MockGRPC.Adapter)

  Now it's time to write your test. To enable mocks, add `use MockGRPC` to your test, and call
  `MockGRPC.expect/2` or `MockGRPC.expect/3` to set expectations.

      defmodule DemoTest do
        use ExUnit.Case, async: true

        use MockGRPC

        test "say_hello/1" do
          MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
            assert %SayHelloRequest{name: "John Doe"} == req
            %SayHelloResponse{message: "Hello John Doe"}
          end)

          assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = Demo.say_hello("John Doe")
        end
      end

  All expectations are defined based on the current process. This means that if you call gRPC from
  a separate process, and this process is not a `Task`*, it won't have access to the expectations
  by default. But there are ways to overcome that. See the "Multi-process collaboration" section.

  *`Task` is supported automatically with no extra code needed due to its native
  [caller tracking](https://hexdocs.pm/elixir/1.15.0/Task.html#module-ancestor-and-caller-tracking).

  ## Multi-process collaboration

  MockGRPC supports multi-process collaboration via two mechanisms:

    1. manually set context
    2. global mode

  ### Manually set context

  In order for other processes to have access to your mocks, you can call `set_context/1`
  on the external process passing the PID of the test.

  ### Global mode

  To support global mode, set your test `async` option to `false`. However, this won't allow
  your test file to execute in parallel with other tests.
  """

  require Logger

  @doc false
  def setup(context) do
    if Process.get(MockGRPC) do
      Logger.warn("Attempted to set up MockGRPC twice. Skipping...")
    else
      do_setup(context)
    end
  end

  defp do_setup(context) do
    test_key = if context.async, do: self(), else: :global
    Process.put(MockGRPC, test_key)

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

  @doc """
  Makes `GRPC.Stub.connect/2` return successfully, reverting the `down/0` call.
  """
  def up do
    test_key = Process.get(MockGRPC)
    MockGRPC.Server.up(test_key)
  end

  @doc """
  Makes `GRPC.Stub.connect/2` return an error tuple.
  """
  def down do
    test_key = Process.get(MockGRPC)
    MockGRPC.Server.down(test_key)
  end

  @doc """
  Adds an expectation using a gRPC service function capture.

  Example:

      MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
        assert %SayHelloRequest{name: "John Doe"} == req
        %SayHelloResponse{message: "Hello John Doe"}
      end)

      assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = Demo.say_hello("John Doe")
  """
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

  @doc """
  Adds an expectation using the gRPC service module and function name.

  Example:

      MockGRPC.expect(GreetService, :say_hello, fn req ->
        assert %SayHelloRequest{name: "John Doe"} == req
        %SayHelloResponse{message: "Hello John Doe"}
      end)

      assert {:ok, %SayHelloResponse{message: "Hello John Doe"}} = Demo.say_hello("John Doe")
  """
  def expect(service_module, fun_name, mock_fun)
      when is_atom(service_module) and is_atom(fun_name) and is_function(mock_fun) do
    test_key = Process.get(MockGRPC)

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
      {MockGRPC.Server, test_key}
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

  @doc """
  Set mock context, in case the mock is being called from another process in an async test.

  This is not needed for `Task` processes.

  Example:

      test "calling a mock from a different process" do
        parent = self()

        MockGRPC.expect(&GreetService.Stub.say_hello/2, fn req ->
          assert %SayHelloRequest{name: "John Doe"} == req
          %SayHelloResponse{message: "Hello John Doe"}
        end)

        # This is just an example to demonstrate the concept. In a real world scenario, you'd
        # be better off using the `Task` module, which doesn't require calling `set_context`
        spawn(fn ->
          # Ensure this process has access to the mocks
          MockGRPC.set_context(parent)

          {:ok, channel} = GRPC.Stub.connect("localhost:50051", adapter: Application.get_env(:demo, :grpc_adapter))
          response = GreetService.Stub.say_hello(channel, %SayHelloRequest{name: "John Doe"})

          # Do the assertion outside the process, to avoid a race condition where the test
          # finishes before this process completes execution.
          send(parent, {:my_process_result, response})
        end)

        assert_receive {:my_process_result, %SayHelloResponse{message: "Hello John Doe"}}
      end
  """
  def set_context(test_key) do
    Process.put(MockGRPC, test_key)
  end

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
