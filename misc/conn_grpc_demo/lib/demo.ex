defmodule Demo do
  alias Demo.DemoPool
  alias Demo.GreetService
  alias Demo.SayHelloRequest

  def say_hello(first_name, last_name) do
    with {:ok, channel} <- DemoPool.get_channel() do
      {:ok,
       GreetService.Stub.say_hello(channel, %SayHelloRequest{
         first_name: first_name,
         last_name: last_name
       })}
    end
  end
end
