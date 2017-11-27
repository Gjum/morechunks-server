defmodule MoreChunks.Client do
  use GenServer

  require Logger

  def start_link(socket) do
    GenServer.start_link(__MODULE__, [socket])
  end

  def init([socket]) do
    {:ok, remote} = :inet.peername(socket)
    Logger.metadata(client: inspect(remote))

    # only receive the single next packet,
    # to prevent swamping the inbox with tcp messages
    # this also has to be called after every time we've received a tcp message
    # ie. in handle_info({:tcp, ...}, ...)
    :inet.setopts(socket, active: :once)

    state = %{
      remote: remote,
      socket: socket,
      chunks_request: [],
      chunks_per_second: 1,
      chunk_send_timer: nil
    }

    Logger.info(inspect([:user_connected]))

    {:ok, state}
  end

  # chunk
  defp handle_packet(0, payload, state) do
    with <<timestamp::64, chunk_packet::binary>> <- payload,
         <<cx::32-signed, cz::32-signed, _::binary>> <- chunk_packet do
      pos = {cx, cz}
      MoreChunks.ChunkStorage.store(pos, chunk_packet)

      packet_size = byte_size(chunk_packet)
      Logger.debug(inspect([:user_contributed_chunk, pos, packet_size]))
    else
      err ->
        Logger.info(inspect([:invalid_user_chunk, err, payload]))
    end

    state
  end

  # info message
  defp handle_packet(1, payload, state) do
    case payload do
      "game.dimension=0" ->
        Logger.info(inspect([:valid_dimension, 0]))

        state

      <<"game.dimension=", invalid_dimension::bytes>> ->
        response = "error.invalid_dimension " <> invalid_dimension
        :ok = :gen_tcp.send(state.socket, <<1::8, response::binary>>)
        Logger.info(inspect([:invalid_dimension, invalid_dimension]))

        # the client should disconnect upon receiving the response,
        # this is so clients that don't understand the response don't auto-reconnect
        Process.sleep(60_000)

        exit({:shutdown, {:client_error, {:invalid_dimension, invalid_dimension}}})

      <<"mod.chunksPerSecond=", val::bytes>> ->
        with {chunks_per_second, ""} <- :string.to_integer(val) do
          Logger.info(inspect([:user_set_chunks_per_second, chunks_per_second]))

          %{state | chunks_per_second: chunks_per_second}
        else
          {:error, :badarg} ->
            Logger.info(inspect([:invalid_chunks_per_second, payload]))

            state
        end

      unknown_payload ->
        Logger.warn(inspect([:user_info_unknown, unknown_payload]))

        state
    end
  end

  # chunks request
  defp handle_packet(2, payload, state) do
    if state.chunk_send_timer != nil do
      Process.cancel_timer(state.chunk_send_timer)
    end

    positions = for <<(<<cx::32-signed, cz::32-signed>> <- payload)>>, do: {cx, cz}
    Logger.debug(inspect([:user_request, positions]))

    send_next_chunk(%{state | chunks_request: positions, chunk_send_timer: nil})
  end

  defp handle_packet(p_type, payload, state) do
    Logger.warn(inspect([:unknown_packet_type, p_type, byte_size(payload)]))

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
        Logger.debug(inspect([:sent_chunk, pos]))

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
    Logger.info(inspect([:user_closed]))
    exit({:shutdown, :tcp_closed})
  end

  def handle_info({:tcp_error, _socket, error}, state) do
    Logger.info(inspect([:tcp_error, error]))
    exit({:shutdown, :tcp_error})
  end

  def handle_info(:send_next_chunk, state) do
    state = send_next_chunk(%{state | chunk_send_timer: nil})
    {:noreply, state}
  end

  def handle_call(:get_state, _caller, state) do
    {:reply, state, state}
  end
end
