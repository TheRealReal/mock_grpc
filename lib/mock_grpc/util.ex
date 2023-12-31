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
      parts |> Enum.drop(-1) |> Enum.concat(["Service"]) |> Module.concat()
    end
  end

  # Get test key from the current process dictionary, or from any of the
  # $callers process dictinary, so that it works with `Task`.
  # More info: https://hexdocs.pm/elixir/1.15.0/Task.html#module-ancestor-and-caller-tracking
  def get_test_key do
    Process.get(MockGRPC) || get_test_key_from_callers(Process.get(:"$callers", [])) || :global
  end

  def get_test_key(pid) do
    dictionary = Process.info(pid)[:dictionary]
    dictionary[MockGRPC] || get_test_key_from_callers(dictionary[:"$callers"] || []) || :global
  end

  defp get_test_key_from_callers([]), do: nil

  defp get_test_key_from_callers([caller | rest]) do
    test_key =
      if info = Process.info(caller) do
        info[:dictionary][MockGRPC]
      end

    test_key || get_test_key_from_callers(rest)
  end
end
