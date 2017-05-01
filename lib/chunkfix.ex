defmodule ChunkFix do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    children = [
      worker(ChunkFix.Server, [12312]),
      worker(ChunkFix.ChunkStorage, []),
    ]

    opts = [strategy: :one_for_one, name: ChunkFix.Supervisor]
    Supervisor.start_link(children, opts)
  end

end
