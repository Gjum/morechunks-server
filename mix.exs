defmodule ChunkFix.Mixfile do
  use Mix.Project

  def project do
    [ app: :chunkfix,
      version: "0.1.0",
      elixir: "~> 1.4",
      build_embedded: Mix.env == :prod,
      start_permanent: Mix.env == :prod,
      deps: deps()
    ]
  end

  def application do
    [ extra_applications: [:logger],
      mod: {ChunkFix, []},
    ]
  end

  defp deps do
    [
      {:socket, "~> 0.3"},
    ]
  end
end
