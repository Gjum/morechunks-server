defmodule MoreChunks.Server do
  require Logger

  def listen(port) do
    Process.register(self(), __MODULE__) # give this process a name
    Logger.info "starting tcp server at port #{inspect port}"
    {:ok, server_sock} = :gen_tcp.listen(port, [mode: :binary, packet: 4, active: false, reuseaddr: true])
    listen_loop(server_sock)
  end

  def listen_loop(server_sock) do
    {:ok, client_sock} = :gen_tcp.accept(server_sock)
    {:ok, _pid} = Task.Supervisor.start_child(MoreChunks.Server.Supervisor, fn -> __MODULE__.serve(client_sock) end)
    __MODULE__.listen_loop(server_sock)
  end

  def serve(client_sock) do
    {:ok, remote} = :inet.peername(client_sock)
    MoreChunks.Metrics.user_connected(remote)
    try do
      result = serve_loop(client_sock, remote)
      MoreChunks.Metrics.user_closed(remote, result)
    after # handler failed
      :gen_tcp.close client_sock
      MoreChunks.Metrics.user_finished(remote)
    end
  end

  def serve_loop(client_sock, remote) do
    with {:ok, data} <- :gen_tcp.recv(client_sock, 0) do
      case MoreChunks.Protocol.handle_packet(data, client_sock, remote) do
        closed_error = {:error, :closed} ->
          closed_error
        :ok ->
          __MODULE__.serve_loop(client_sock, remote)
        error ->
          MoreChunks.Metrics.handler_error(remote, error)
          __MODULE__.serve_loop(client_sock, remote)
      end
    end
  end

end
