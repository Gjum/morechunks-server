defmodule MoreChunks.Server do
  use Task, restart: :permanent, id: __MODULE__

  def start_link(ip, port) do
    Task.start_link(__MODULE__, :init, [ip, port])
  end

  def get_client_pids() do
    Supervisor.which_children(MoreChunks.Server.ClientSupervisor)
    |> Enum.map(&elem(&1, 1))
  end

  def init(ip, port) do
    Process.register(self(), __MODULE__)

    {:ok, listen_socket} =
      :gen_tcp.listen(
        port,
        ip: ip,
        mode: :binary,
        packet: 4,
        active: false,
        reuseaddr: true
      )

    {:ok, sup_pid} = start_clients_supervisor()

    listen_loop(listen_socket, sup_pid)
  end

  def listen_loop(listen_socket, sup_pid) do
    {:ok, client_socket} = :gen_tcp.accept(listen_socket)

    {:ok, client} = Supervisor.start_child(sup_pid, [client_socket])
    :gen_tcp.controlling_process(client_socket, client)

    __MODULE__.listen_loop(listen_socket, sup_pid)
  end

  def start_clients_supervisor() do
    import Supervisor.Spec

    children = [
      worker(MoreChunks.Client, [], restart: :temporary)
    ]

    # We start a supervisor with a simple one for one strategy.
    # The clients won't be started now but later on,
    # see Supervisor.start_child above.
    Supervisor.start_link(
      children,
      strategy: :simple_one_for_one,
      name: MoreChunks.Server.ClientSupervisor
    )
  end
end
