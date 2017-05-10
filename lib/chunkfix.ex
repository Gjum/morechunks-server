defmodule ChunkFix do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, warn: false

    listen_port = 12312 # TODO get from args

    children = [
      worker(ChunkFix.Metrics, []),
      worker(ChunkFix.ChunkStorage, []),
      supervisor(Task.Supervisor, [[name: ChunkFix.Server.Supervisor]]),
      worker(Task, [ChunkFix.Server, :listen, [listen_port]]),
    ]

    opts = [strategy: :one_for_one, name: ChunkFix.Supervisor]
    Supervisor.start_link(children, opts)
  end

  def nice_pos(pos_long) do
    <<cx::32-signed, cz::32-signed>> = pos_long
    {cx, cz}
  end

end
