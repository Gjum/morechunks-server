defmodule ChunkFix.Protocol do
  use Bitwise, only_operators: true

  require Logger

  def handle_packet(data, client_sock, remote) do
    <<p_type::8, payload::binary>> = data
    case p_type do

      0 ->
        <<timestamp::64, chunk_packet::binary>> = payload
        <<pos_long::binary-8, _::binary>> = chunk_packet
        ChunkFix.ChunkStorage.store(pos_long, chunk_packet)
        ChunkFix.Metrics.user_contributed_chunk(remote, pos_long, byte_size chunk_packet)
        :ok

      1 ->
        ChunkFix.Metrics.user_info(remote, payload)
        :ok

      2 ->
        positions = for << <<pos_long::binary-8>> <- payload >>, do: pos_long
        ChunkFix.Metrics.user_request(remote, positions)
        respond_chunks(positions, client_sock, remote)
        
      p_type ->
        Logger.debug "unknown packet type #{p_type} with #{byte_size payload} bytes payload"

    end
  end

  defp respond_chunks([], _client_sock, _remote), do: :ok
  defp respond_chunks([pos_long | positions], client_sock, remote) do
    chunk_packet = ChunkFix.ChunkStorage.retrieve(pos_long)
    case chunk_packet do
      "" -> respond_chunks(positions, client_sock, remote)
      chunk_packet ->
        with :ok <- :gen_tcp.send(client_sock, <<0::8, chunk_packet::binary>>) do
          ChunkFix.Metrics.sent_chunk(remote, pos_long)
          respond_chunks(positions, client_sock, remote)
        end
    end
  end

end
