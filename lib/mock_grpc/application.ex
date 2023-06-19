defmodule MockGRPC.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [
      {DynamicSupervisor, strategy: :one_for_one, name: MockGRPC.DynamicSupervisor},
      {Registry, name: MockGRPC.Registry, keys: :unique}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: MockGRPC.Supervisor)
  end
end
