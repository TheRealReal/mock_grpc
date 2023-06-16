defmodule MockGRPCTest do
  use ExUnit.Case
  doctest MockGRPC

  test "greets the world" do
    assert MockGRPC.hello() == :world
  end
end
