defmodule MoreChunks.ChunkStorage do
  use GenServer

  require Logger

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Store the serialized chunk.

  ## Parameters
    - position: 64Bit number representing the chunk cordinates.
    - chunk_data: serialized chunk in the form of a Chunk Data packet.
  """
  def store(position, chunk_data) do
    # TODO timestamp
    GenServer.cast(__MODULE__, {:store, position, chunk_data})
  end

  @doc """
  Retrieve a serialized chunk.

  ## Parameters
    - position: 64Bit number representing the chunk cordinates.
  """
  def retrieve(position) do
    GenServer.call(__MODULE__, {:retrieve, position})
  end

  @doc "Retrieve the positions of all stored chunks."
  def get_stored() do
    GenServer.call(__MODULE__, :get_stored)
  end

  ## Server Callbacks

  def init(_args) do
    MoreChunks.Metrics.cast([:start_module, __MODULE__])
    {:ok, %{}}
  end

  def handle_cast({:store, position, chunk_data}, storage) do
    {old_packet, storage} =
      Map.get_and_update(storage, position, fn old_packet -> {old_packet, chunk_data} end)

    if old_packet == nil do
      MoreChunks.Metrics.cast([:chunk_creation, position, byte_size(chunk_data)])
    else
      bs_old = byte_size(old_packet)
      bs_new = byte_size(chunk_data)
      MoreChunks.Metrics.cast([:chunk_update, position, bs_old, bs_new])
    end

    spawn_link(fn -> save_chunk(position, chunk_data) end)

    # TODO if close to memory limit, purge oldest chunks

    {:noreply, storage}
  end

  def handle_call({:retrieve, position}, from, storage) do
    case Map.fetch(storage, position) do
      {:ok, chunk} ->
        MoreChunks.Metrics.cast([:chunk_lookup_hit, position])

        {:reply, chunk, storage}

      :error ->
        load_chunk_async(position, from)
        {:noreply, storage}
    end
  end

  def handle_call(:get_stored, _from, storage) do
    positions =
      Map.keys(storage)
      |> Enum.map(&MoreChunks.nice_pos/1)

    {:reply, positions, storage}
  end

  def load_chunk_async(position, receiver) do
    spawn_link(fn ->
      chunk_data = load_chunk(MoreChunks.nice_pos(position))

      GenServer.reply(receiver, chunk_data)

      case chunk_data do
        nil ->
          MoreChunks.Metrics.cast([:chunk_lookup_miss, position])

        chunk_data ->
          MoreChunks.Metrics.cast([:chunk_loaded, position])
          GenServer.cast(__MODULE__, {:store, position, chunk_data})
      end
    end)
  end

  def load_chunk(position, config \\ %{storage_path: "mccp_storage"}) do
    region_path = get_region_path(position, config)
    chunk_path = "#{region_path}/#{get_chunk_filename(position)}"

    status = File.open(chunk_path, [:read, :compressed], &IO.binread(&1, :all))

    # convert inner (read) error to outer error
    status =
      case status do
        {:ok, {:error, err}} -> {:error, err}
        other -> other
      end

    case status do
      {:ok, chunk_data} ->
        chunk_data

      {:error, :enoent} ->
        nil

      {:error, err} ->
        MoreChunks.Metrics.cast([:chunk_load_error, position, err])
        nil
    end
  end

  def save_chunk(position, chunk_data, config \\ %{storage_path: "mccp_storage"}) do
    region_path = get_region_path(position, config)
    File.mkdir_p!(region_path)
    chunk_path = "#{region_path}/#{get_chunk_filename(position)}"

    status = File.open(chunk_path, [:write, :compressed], &IO.binwrite(&1, chunk_data))

    case status do
      {:ok, _} ->
        :ok

      {:error, err} ->
        MoreChunks.Metrics.cast([:chunk_save_error, position, err])
        {:error, err}
    end
  end

  defp get_chunk_filename({cx, cz}) do
    "#{cx}_#{cz}.mccp"
  end

  defp get_region_path({cx, cz}, config) do
    # TODO -2 -> 0, should be -2 -> -1
    rx = div(cx, 32)
    rz = div(cz, 32)
    region_dir = "r_#{rx}_#{rz}"
    "#{config.storage_path}/#{region_dir}"
  end
end
