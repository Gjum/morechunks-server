defmodule ChunkFix.Protocol do
  use Bitwise, only_operators: true

  require Logger

  def handle_packet(data, client_sock) do
    <<p_type::8, payload::binary>> = data
    case p_type do

      0 ->
        <<timestamp::64, chunk_packet::binary>> = payload
        <<pos_long::binary-8, _::binary>> = chunk_packet

        ChunkFix.ChunkStorage.store(pos_long, chunk_packet)
        :ok

      1 ->
        Logger.info("received info: #{payload}")
        :ok

      2 ->
        positions = for << <<pos_long::binary-8>> <- payload >>, do: pos_long
        respond_chunks(positions, client_sock)

      p_type ->
        Logger.debug "unknown packet type #{p_type} with #{byte_size payload} bytes payload"

    end
  end

  defp respond_chunks([], _client_sock), do: :ok
  defp respond_chunks([pos_long | positions], client_sock) do
    chunk_packet = ChunkFix.ChunkStorage.retrieve(pos_long)
    with :ok <- :gen_tcp.send(client_sock, <<0::8, chunk_packet::binary>>),
      do: respond_chunks(positions, client_sock)
  end

  def nice_pos(pos_long) do
    <<cx::32-signed, cz::32-signed>> = pos_long
    {cx, cz}
  end

end
