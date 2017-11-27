defmodule MoreChunks do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec

    listen_ip = Application.get_env(:morechunks, :listen_ip, {127, 0, 0, 1})
    listen_port = Application.get_env(:morechunks, :listen_port, 12312)

    children = [
      worker(MoreChunks.ChunkStorage, []),
      supervisor(MoreChunks.ClientSupervisor, []),
      worker(
        MoreChunks.Server,
        [listen_ip, listen_port],
        restart: :permanent,
        id: MoreChunks.Server
      )
    ]

    Supervisor.start_link(
      children,
      strategy: :one_for_one,
      name: MoreChunks.Supervisor
    )
  end
end
