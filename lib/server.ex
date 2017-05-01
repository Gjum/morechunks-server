defmodule ChunkFix.Server do
  require Logger

  def start_link(port) do
    pid = spawn_link(fn -> init(port) end)
    {:ok, pid}
  end

  defp init(port) do
    tcp_options = [:list, {:packet, 0}, {:active, false}, {:reuseaddr, true}]
    {:ok, listen_socket} = :gen_tcp.listen(port, tcp_options)
    listen_loop(listen_socket)
  end

  defp listen_loop(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    spawn(fn() -> serve_loop(socket) end)
    listen_loop(listen_socket)
  end

  defp serve_loop(socket) do
    case :gen_tcp.recv(socket, 0) do

      {:ok, data} ->
        Logger.debug(inspect data)
        # ChunkFix.ChunkStorage.store()
        # ChunkFix.ChunkStorage.lookup()
        # :gen_tcp.send(socket, "#{response}\n")
        serve_loop(socket)

      {:error, :closed} -> :ok

    end
  end

end
