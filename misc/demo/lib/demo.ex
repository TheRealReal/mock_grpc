defmodule Demo do
  alias Demo.GreetService
  alias Demo.SayHelloRequest

  def say_hello(first_name, last_name) do
    with {:ok, channel} <-
           GRPC.Stub.connect("localhost:50020", adapter: Application.get_env(:demo, :grpc_adapter)) do
      {:ok,
       GreetService.Stub.say_hello(channel, %SayHelloRequest{
         first_name: first_name,
         last_name: last_name
       })}
    end
  end
end
