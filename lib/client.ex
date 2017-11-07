defmodule MoreChunks.Client do
  use GenServer

  require Logger

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

    MoreChunks.Metrics.user_connected(remote)

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
    %{remote: remote} = state

    <<timestamp::64, chunk_packet::binary>> = payload
    <<pos_long::binary-8, _::binary>> = chunk_packet
    MoreChunks.Metrics.user_contributed_chunk(remote, pos_long, byte_size(chunk_packet))

    MoreChunks.ChunkStorage.store(pos_long, chunk_packet)

    state
  end

  # info message
  defp handle_packet(1, payload, state) do
    %{remote: remote} = state

    case payload do
      <<"mod.chunksPerSecond=", val::bytes>> ->
        {chunks_per_second, ""} = :string.to_integer(val)
        MoreChunks.Metrics.user_set_chunks_per_second(remote, chunks_per_second)

        %{state | chunks_per_second: chunks_per_second}

      unknown_payload ->
        MoreChunks.Metrics.user_info_unknown(remote, unknown_payload)

        state
    end
  end

  # chunks request
  defp handle_packet(2, payload, state) do
    %{remote: remote, chunk_send_timer: timer} = state

    if timer != nil do
      Process.cancel_timer(timer)
    end

    positions = for <<(<<pos_long::binary-8>> <- payload)>>, do: pos_long
    MoreChunks.Metrics.user_request(remote, positions)

    send_next_chunk(%{state | chunks_request: positions})
  end

  defp handle_packet(p_type, payload, state) do
    %{remote: remote} = state

    MoreChunks.Metrics.user_connection_error(
      remote,
      {:unknown_packet_type, p_type, byte_size(payload)}
    )

    state
  end

  defp send_next_chunk(state = %{chunks_request: []}) do
    state
  end

  defp send_next_chunk(state = %{chunks_request: [pos_long | remaining_positions]}) do
    chunk_packet = MoreChunks.ChunkStorage.retrieve(pos_long)

    case chunk_packet do
      "" ->
        # skip unknown chunk
        send_next_chunk(%{state | chunks_request: remaining_positions})

      chunk_packet ->
        %{remote: remote, socket: socket} = state

        with :ok <- :gen_tcp.send(socket, <<0::8, chunk_packet::binary>>) do
          MoreChunks.Metrics.sent_chunk(remote, pos_long)
        end

        %{chunks_per_second: chunks_per_second} = state
        ms_to_next_chunk_send = div(1000, chunks_per_second)

        timer = Process.send_after(self(), :send_next_chunk, ms_to_next_chunk_send)

        %{state | chunks_request: remaining_positions, chunk_send_timer: timer}
    end
  end

  def handle_info({:tcp, socket, packet_data}, state) do
    # only receive the single next packet,
    # to prevent swamping the inbox with tcp messages
    :inet.setopts(socket, active: :once)

    <<p_type::8, payload::binary>> = packet_data
    state = handle_packet(p_type, payload, state)

    {:noreply, state}
  end

  def handle_info({:tcp_closed, _socket}, %{remote: remote}) do
    MoreChunks.Metrics.user_closed(remote)
    exit({:shutdown, :tcp_closed})
  end

  def handle_info({:tcp_error, _socket, reason}, %{remote: remote}) do
    MoreChunks.Metrics.user_connection_error(remote, {:tcp_error, reason})
    exit({:shutdown, :tcp_error})
  end

  def handle_info(:send_next_chunk, state) do
    state = send_next_chunk(state)
    {:noreply, state}
  end

  def handle_call(:get_chunks_request, _caller, state) do
    %{chunks_request: chunks_request} = state
    {:reply, chunks_request, state}
  end
end
