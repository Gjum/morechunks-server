defmodule ChunkFix.ChunkStorage do
  use GenServer

  require Logger

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  @doc """
  Store the serialized chunk.

  ## Parameters
    - position: 64Bit number representing the chunk cordinates.
    - packet_data: serialized chunk in the form of a Chunk Data packet.
  """
  def store(position, packet_data) do
    # TODO timestamp
    GenServer.cast(__MODULE__, {:store, position, packet_data})
  end

  @doc """
  Retrieve a serialized chunk.

  ## Parameters
    - position: 64Bit number representing the chunk cordinates.
  """
  def retrieve(position) do
    GenServer.call(__MODULE__, {:retrieve, position})
  end

  ## Server Callbacks

  def init(args) do
    Logger.info "Starting ChunkStorage, args: #{inspect args}"
    {:ok, %{}}
  end

  def terminate(reason, _state) do
    Logger.warn "Terminating ChunkStorage, reason: #{inspect reason}"
  end

  def handle_cast({:store, position, packet_data}, storage) do
    {old_packet, storage} = Map.get_and_update(storage, position, fn old_packet -> {old_packet, packet_data} end)
    if old_packet == nil do
      ChunkFix.Metrics.chunk_creation(position, byte_size(packet_data))
    else
      ChunkFix.Metrics.chunk_update(position, byte_size(packet_data), byte_size(old_packet))
    end
    {:noreply, storage}
  end

  def handle_call({:retrieve, position}, _from, storage) do
    chunk = case Map.fetch(storage, position) do
      {:ok, chunk} ->
        ChunkFix.Metrics.chunk_lookup_hit(position)
        chunk
      :error ->
        ChunkFix.Metrics.chunk_lookup_miss(position)
        "" # TODO get from disk
    end
    {:reply, chunk, storage}
  end

end
