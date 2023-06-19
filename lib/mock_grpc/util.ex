defmodule MockGRPC.Util do
  @moduledoc false

  def extract_grpc_fun(fun) when is_function(fun) do
    info = Function.info(fun)

    with :external <- info[:type],
         mod when mod != nil <- extract_service_module(info[:module]) do
      %{service_module: mod, fun_name: info[:name]}
    else
      _ -> nil
    end
  end

  defp extract_service_module(mod) do
    parts = Module.split(mod)

    if List.last(parts) == "Stub" do
      parts |> Enum.drop(-1) |> Module.concat()
    end
  end

  # Get test key from the current process dictionary, or from any of the
  # $callers process dictinary, so that it works with `Task`.
  # More info: https://hexdocs.pm/elixir/1.15.0/Task.html#module-ancestor-and-caller-tracking
  def get_test_key do
    Process.get(MockGRPC) || get_test_key_from_callers() || :global
  end

  defp get_test_key_from_callers do
    callers = Process.get(:"$callers", [])
    get_test_key_from_callers(callers)
  end

  defp get_test_key_from_callers([]), do: nil

  defp get_test_key_from_callers([caller | rest]) do
    test_key = Process.info(caller)[:dictionary][MockGRPC]
    test_key || get_test_key_from_callers(rest)
  end
end
