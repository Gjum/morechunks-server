defmodule ChunkFix do
  def listen(port) do
    tcp_options = [:list, {:packet, 0}, {:active, false}, {:reuseaddr, true}]
    {:ok, listen_socket} = :gen_tcp.listen(port, tcp_options)
    do_listen(listen_socket)
  end

  defp do_listen(listen_socket) do
    {:ok, socket} = :gen_tcp.accept(listen_socket)
    spawn(fn() -> do_server(socket) end)
    do_listen(listen_socket)
  end

  defp do_server(socket) do
    case :gen_tcp.recv(socket, 0) do
      {:ok, data} ->
        responder = spawn(fn() -> do_respond(socket) end)
        spawn(Job, :handle_request, [responder, list_to_binary(data)])
        do_server(socket)

      {:error, :closed} -> :ok
    end
  end

  defp do_respond(socket) do
    receive do
      {:ok, response} ->
        :gen_tcp.send(socket, "#{response}\n")
        Logger.log(response)
    end
  end
end
