defmodule MoreChunks.ChunkStorage do
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

  def get_stored() do
    GenServer.call(__MODULE__, :get_stored)
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
      MoreChunks.Metrics.chunk_creation(position, byte_size(packet_data))
    else
      MoreChunks.Metrics.chunk_update(position, byte_size(packet_data), byte_size(old_packet))
    end
    {:noreply, storage}
  end

  def handle_call({:retrieve, position}, _from, storage) do
    chunk = case Map.fetch(storage, position) do
      {:ok, chunk} ->
        MoreChunks.Metrics.chunk_lookup_hit(position)
        chunk
      :error ->
        MoreChunks.Metrics.chunk_lookup_miss(position)
        "" # TODO get from disk
    end
    {:reply, chunk, storage}
  end

  def handle_call(:get_stored, _from, storage) do
    positions =
      Map.keys(storage)
      |> Enum.map(&MoreChunks.nice_pos/1)

    {:reply, positions, storage}
  end
end
