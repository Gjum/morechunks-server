defmodule MoreChunks.Mixfile do
  use Mix.Project

  def project do
    [
      app: :morechunks,
      version: "1.0.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env() == :prod,
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger],
      mod: {MoreChunks, []}
    ]
  end

  defp deps do
    [
      {:logger_file_backend, "0.0.10"}
    ]
  end
end
