defmodule MockGRPC do
  @moduledoc """
  To mock gRPC calls in the test suite you must add the following block to your test file

    setup do
      MockGRPC.setup()
    end

  then, use `MockGRPC.expect/2` to validate the calls. The first arg is the request module, followed by a fn that
  takes the mocked fn's arguments and returns your custom result.

  note: must be run async: false for now
  """

  def setup do
    ExUnit.Callbacks.on_exit(fn ->
      check_expectations()
      MockGRPC.Server.clear_state()
    end)

    :ok
  end

  def check_expectations do
    state = MockGRPC.Server.get_expectations()

    failures =
      Enum.filter(state, fn %{called: called} ->
        called == false
      end)

    if failures != [] do
      formatted_failures =
        Enum.map(failures, fn %{request_module: req} ->
          "Expected to receive gRPC call to #{req} module but didn't"
        end)

      raise Enum.join(formatted_failures, "\n")
    end
  end

  def expect(request_mod, fun), do: MockGRPC.Server.expect(request_mod, fun)
end
