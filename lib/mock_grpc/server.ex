defmodule MockGRPC.Server do
  use Agent

  def start_link(_) do
    Agent.start_link(fn -> [] end, name: __MODULE__)
  end

  def expect(request_module, fun) do
    Agent.update(__MODULE__, fn state ->
      state ++ [%{request_module: request_module, fun: fun, called: false}]
    end)
  end

  def call(request_mod) do
    Agent.get_and_update(__MODULE__, fn state ->
      index =
        Enum.find_index(state, fn
          %{request_module: ^request_mod} -> true
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
