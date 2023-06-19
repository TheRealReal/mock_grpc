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
end
