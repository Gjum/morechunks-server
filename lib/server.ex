defmodule ChunkFix.Server do
  require Logger

  def listen(port) do
    Process.register(self(), __MODULE__) # give this process a name
    Logger.info "starting tcp server at port #{inspect port}"
    {:ok, server_sock} = :gen_tcp.listen(port, [mode: :binary, packet: 4, active: false, reuseaddr: true])
    listen_loop(server_sock)
  end

  def listen_loop(server_sock) do
    {:ok, client_sock} = :gen_tcp.accept(server_sock)
    {:ok, pid} = Task.Supervisor.start_child(ChunkFix.Server.Supervisor, fn -> serve(client_sock) end)
    __MODULE__.listen_loop(server_sock)
  end

  def serve(client_sock) do
    :gen_tcp.controlling_process(client_sock, self())
    {:ok, remote} = :inet.peername(client_sock)
    Logger.debug "New connection from #{inspect remote}"
    result = serve_loop(client_sock)
    Logger.debug "Connection closed at #{inspect remote} with #{inspect result}"
  end

  def serve_loop(client_sock) do
    with {:ok, data} <- :gen_tcp.recv(client_sock, 0),
         :ok <- ChunkFix.Protocol.handle_packet(data, client_sock) do
      __MODULE__.serve_loop(client_sock)
    end
  end

end
