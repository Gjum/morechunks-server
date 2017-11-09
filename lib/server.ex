defmodule MoreChunks.Server do
  def start_link(ip, port) do
    Task.start_link(__MODULE__, :init, [ip, port])
  end

  def init(ip, port) do
    Process.register(self(), __MODULE__)
    MoreChunks.Metrics.cast([:start_module, __MODULE__])

    {:ok, listen_socket} =
      :gen_tcp.listen(
        port,
        ip: ip,
        mode: :binary,
        packet: 4,
        active: false,
        reuseaddr: true
      )

    listen_loop(listen_socket)
  end

  def listen_loop(listen_socket) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)

    {:ok, client} = Supervisor.start_child(MoreChunks.ClientSupervisor, [client_socket])
    :gen_tcp.controlling_process(client_socket, client)

    __MODULE__.listen_loop(listen_socket)
  end
end
