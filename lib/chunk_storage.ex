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
    Logger.info "Storing chunk at #{inspect position}, size: #{inspect byte_size(packet_data)}"
    {:noreply, Map.put(storage, position, packet_data)}
  end

  def handle_call({:retrieve, position}, _from, storage) do
    chunk = case Map.fetch(storage, position) do
      {:ok, chunk} -> chunk
      :error -> "" # TODO get from disk
    end
    {:reply, chunk, storage}
  end

end
