defmodule ChunkFix.Protocol do
  use Bitwise, only_operators: true

  require Logger

  def handle_packet(data, client_sock) do
    <<p_type::8, payload::binary>> = data
    case p_type do

      0 ->
        <<timestamp::64, chunk_packet::binary>> = payload
        <<cx::32, cz::32, _::binary>> = chunk_packet
        pos = {:chunk_pos, cx, cz}
        Logger.debug("received chunk at #{inspect pos} of size #{inspect(byte_size chunk_packet)}, created #{inspect timestamp}")
        ChunkFix.ChunkStorage.store(pos, chunk_packet)
        :ok

      1 ->
        Logger.info("received info: #{payload}")
        :ok

      2 ->
        # TODO ChunkFix.ChunkStorage.lookup()
        :ok

      p_type ->
        Logger.debug "unknown packet type #{p_type} with #{byte_size payload} bytes payload"

    end
  end

end
