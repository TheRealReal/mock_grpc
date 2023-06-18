defmodule MockGRPC.Server do
  # `MockGRPC.Server` is a process that keeps all expectations for the current test,
  # and pops them from the expectation list when the mock is called.
  #
  # Each test that uses `MockGRPC` will spawn its own `MockGRPC.Server` instance, and
  # the process name is tracked via `MockGRPC.Registry`, allowing for each test to have
  # access to their own state.
  #
  # If the test is async, the key of the process in the registry will be the test PID
  # This allows tests to run concurrently while keeping their own set of mocks and
  # expectations.
  #
  # If the test is sync, the key of the process will be `:global`. This allows for writing
  # tests that call gRPC from other processes, while having mocks and expectations working.

  @moduledoc false

  use Agent

  def start_link(opts) do
    Agent.start_link(fn -> [] end, name: name(opts[:test_key]))
  end

  def expect(test_key, service_module, fun_name, mock_fun) do
    service_name = service_module.__meta__(:name)

    expectation = %{
      service_module: service_module,
      service_name: service_name,
      fun_name: to_string(fun_name),
      mock_fun: mock_fun
    }

    Agent.update(
      name(test_key),
      fn state -> state ++ [expectation] end
    )
  end

  def call(test_key, service_name, fun_name) do
    Agent.get_and_update(name(test_key), fn state ->
      index =
        Enum.find_index(state, fn
          %{service_name: ^service_name, fun_name: ^fun_name} -> true
          _else -> false
        end)

      if index do
        List.pop_at(state, index)
      else
        {nil, state}
      end
    end)
  end

  def get_expectations(test_key) do
    Agent.get(name(test_key), fn state -> state end)
  end

  def clear_state(test_key) do
    Agent.update(name(test_key), fn _ -> [] end)
  end

  def name(test_key), do: {:via, Registry, {MockGRPC.Registry, test_key}}
end
