defmodule MockGRPC.MixProject do
  use Mix.Project

  @source_url "https://github.com/TheRealReal/mock_grpc"
  @version "0.2.0"

  def project do
    [
      app: :mock_grpc,
      version: @version,
      name: "MockGRPC",
      description: "Concurrent mocks for gRPC Elixir",
      elixir: "~> 1.12",
      deps: deps(),
      docs: docs(),
      package: package(),
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env())
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MockGRPC.Application, []}
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:grpc, "~> 0.6 or ~> 0.11"},
      {:protobuf, "~> 0.14.1", only: :test},
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false}
    ]
  end

  defp package do
    [
      maintainers: ["TheRealReal"],
      licenses: ["Apache-2.0"],
      links: %{"GitHub" => @source_url}
    ]
  end

  defp docs do
    [
      main: "MockGRPC",
      source_ref: "v#{@version}",
      canonical: "http://hexdocs.pm/mock_grpc",
      source_url: @source_url,
      extras: [
        "guides/conn_grpc.md": [filename: "conn_grpc", title: "Integrating with ConnGRPC"]
      ]
    ]
  end
end
