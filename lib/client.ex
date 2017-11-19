defmodule MoreChunks.Client do
  use GenServer

  def start_link(socket) do
    GenServer.start_link(__MODULE__, [socket])
  end

  def init([socket]) do
    {:ok, remote} = :inet.peername(socket)

    # only receive the single next packet,
    # to prevent swamping the inbox with tcp messages
    # this also has to be called after every time we've received a tcp message
    # ie. in handle_info({:tcp, ...}, ...)
    :inet.setopts(socket, active: :once)

    MoreChunks.Metrics.cast([:user_connected], remote)

    {:ok, %{
      remote: remote,
      socket: socket,
      chunks_request: [],
      chunks_per_second: 1,
      chunk_send_timer: nil
    }}
  end

  # chunk
  defp handle_packet(0, payload, state) do
    with <<timestamp::64, chunk_packet::binary>> <- payload,
         <<cx::32-signed, cz::32-signed, _::binary>> <- chunk_packet do
      pos = {cx, cz}
      MoreChunks.ChunkStorage.store(pos, chunk_packet)

      packet_size = byte_size(chunk_packet)
      MoreChunks.Metrics.cast([:user_contributed_chunk, pos, packet_size], state.remote)
    else
      err ->
        MoreChunks.Metrics.cast([:invalid_user_chunk, err, payload], state.remote)
    end

    state
  end

  # info message
  defp handle_packet(1, payload, state) do
    case payload do
      "game.dimension=0" ->
        MoreChunks.Metrics.cast([:valid_dimension, 0], state.remote)

        state

      <<"game.dimension=", invalid_dimension::bytes>> ->
        response = "error.invalid_dimension " <> invalid_dimension
        :ok = :gen_tcp.send(state.socket, <<1::8, response::binary>>)
        MoreChunks.Metrics.cast([:invalid_dimension, invalid_dimension], state.remote)

        # the client should disconnect upon receiving the response,
        # this is so clients that don't understand the response don't auto-reconnect
        Process.sleep(60_000)

        exit({:shutdown, {:client_error, {:invalid_dimension, invalid_dimension}}})

      <<"mod.chunksPerSecond=", val::bytes>> ->
        with {chunks_per_second, ""} <- :string.to_integer(val) do
          MoreChunks.Metrics.cast([:user_set_chunks_per_second, chunks_per_second], state.remote)

          %{state | chunks_per_second: chunks_per_second}
        else
          {:error, :badarg} ->
            MoreChunks.Metrics.cast([:invalid_chunks_per_second, payload], state.remote)

            state
        end

      unknown_payload ->
        MoreChunks.Metrics.cast([:user_info_unknown, unknown_payload], state.remote)

        state
    end
  end

  # chunks request
  defp handle_packet(2, payload, state) do
    if state.chunk_send_timer != nil do
      Process.cancel_timer(state.chunk_send_timer)
    end

    positions = for <<(<<cx::32-signed, cz::32-signed>> <- payload)>>, do: {cx, cz}
    MoreChunks.Metrics.cast([:user_request, positions], state.remote)

    send_next_chunk(%{state | chunks_request: positions, chunk_send_timer: nil})
  end

  defp handle_packet(p_type, payload, state) do
    MoreChunks.Metrics.cast([:unknown_packet_type, p_type, byte_size(payload)], state.remote)

    state
  end

  defp send_next_chunk(state = %{chunks_request: []}) do
    state
  end

  defp send_next_chunk(state = %{chunks_request: [pos | remaining_positions]}) do
    chunk_packet = MoreChunks.ChunkStorage.retrieve(pos)

    case chunk_packet do
      nil ->
        # skip unknown chunk
        send_next_chunk(%{state | chunks_request: remaining_positions})

      chunk_packet ->
        :ok = :gen_tcp.send(state.socket, <<0::8, chunk_packet::binary>>)
        MoreChunks.Metrics.cast([:sent_chunk, pos], state.remote)

        config_chunks_per_second = Application.get_env(:morechunks, :max_chunks_per_second, 80)
        chunks_per_second = min(state.chunks_per_second, config_chunks_per_second)
        ms_to_next_chunk_send = div(1000, chunks_per_second)

        timer = Process.send_after(self(), :send_next_chunk, ms_to_next_chunk_send)

        %{state | chunks_request: remaining_positions, chunk_send_timer: timer}
    end
  end

  # GenServer handlers

  def handle_info({:tcp, socket, packet_data}, state) do
    <<p_type::8, payload::binary>> = packet_data
    state = handle_packet(p_type, payload, state)

    # only receive the single next packet,
    # to prevent swamping the inbox with tcp messages
    :inet.setopts(socket, active: :once)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    MoreChunks.Metrics.cast([:user_closed], state.remote)
    exit({:shutdown, :tcp_closed})
  end

  def handle_info({:tcp_error, _socket, error}, state) do
    MoreChunks.Metrics.cast([:tcp_error, error], state.remote)
    exit({:shutdown, :tcp_error})
  end

  def handle_info(:send_next_chunk, state) do
    state = send_next_chunk(%{state | chunk_send_timer: nil})
    {:noreply, state}
  end

  def handle_call(:get_chunks_request, _caller, state) do
    {:reply, state.chunks_request, state}
  end
end
