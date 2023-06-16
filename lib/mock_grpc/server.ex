defmodule MockGRPC.Server do
  @moduledoc false

  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def expect(service_module, fun_name, mock_fun) do
    service_name = service_module.__meta__(:name)

    expectation = %{
      service_module: service_module,
      service_name: service_name,
      fun_name: to_string(fun_name),
      mock_fun: mock_fun,
      called: false
    }

    Agent.update(__MODULE__, fn state -> state ++ [expectation] end)
  end

  def call(service_name, fun_name) do
    Agent.get_and_update(__MODULE__, fn state ->
      index =
        Enum.find_index(state, fn
          %{service_name: ^service_name, fun_name: ^fun_name} -> true
          _else -> false
        end)

      if index do
        state =
          List.update_at(state, index, fn expectation -> Map.put(expectation, :called, true) end)

        expectation = Enum.at(state, index)
        {expectation, state}
      else
        {nil, state}
      end
    end)
  end

  def get_expectations do
    Agent.get(__MODULE__, fn state -> state end)
  end

  def clear_state do
    Agent.update(__MODULE__, fn _ -> [] end)
  end
end
