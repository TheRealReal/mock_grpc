defmodule Demo do
  alias Demo.TestService
  alias Demo.HelloWorldRequest

  def say_hello(first_name, last_name) do
    with {:ok, channel} <-
           GRPC.Stub.connect("localhost:50020", adapter: Application.get_env(:demo, :grpc_adapter)) do
      {:ok,
       TestService.Stub.hello_world(channel, %HelloWorldRequest{
         first_name: first_name,
         last_name: last_name
       })}
    end
  end
end
