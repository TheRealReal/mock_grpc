defmodule MockGRPC.Application do
  @moduledoc false

  use Application

  def start(_type, _args) do
    children = [MockGRPC.Server]
    Supervisor.start_link(children, strategy: :one_for_one, name: MockGRPC.Supervisor)
  end
end
