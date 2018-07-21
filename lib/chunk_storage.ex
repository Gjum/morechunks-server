defmodule MoreChunks.ChunkStorage do
  use GenServer

  require Logger

  @type position :: {integer, integer}
  @type chunk_data :: binary
  @type storage_config :: %{:storage_path => binary, optional(any) => any}

  @default_conf %{storage_path: "mccp_storage"}

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc "Store the serialized chunk."
  @spec store(position, chunk_data) :: :ok
  def store(position, chunk_data) do
    # TODO timestamp
    GenServer.cast(__MODULE__, {:store, position, chunk_data})
  end

  @doc "Retrieve a serialized chunk."
  @spec retrieve(position) :: chunk_data | nil
  def retrieve(position) do
    GenServer.call(__MODULE__, {:retrieve, position})
  end

  @doc "Retrieve the positions of all stored chunks."
  @spec get_stored() :: [position]
  def get_stored() do
    GenServer.call(__MODULE__, :get_stored)
  end

  ## Server Callbacks

  def init(_args) do
    Logger.info(inspect([:start_module, __MODULE__]))
    {:ok, %{}}
  end

  def handle_cast({:store, position, chunk_data}, storage) do
    {old_packet, storage} =
      Map.get_and_update(storage, position, fn old_packet -> {old_packet, chunk_data} end)

    if old_packet == nil do
      # TODO this could also be an update if the chunk was stored on disk already
      Logger.debug(inspect([:chunk_creation, position, byte_size(chunk_data)]))
    else
      bs_old = byte_size(old_packet)
      bs_new = byte_size(chunk_data)
      Logger.debug(inspect([:chunk_update, position, bs_old, bs_new]))
    end

    spawn_link(fn -> save_chunk(position, chunk_data) end)

    # TODO if close to memory limit, purge oldest chunks

    {:noreply, storage}
  end

  def handle_call({:retrieve, position}, from, storage) do
    case Map.fetch(storage, position) do
      {:ok, chunk} ->
        Logger.debug(inspect([:chunk_lookup_hit, position]))

        {:reply, chunk, storage}

      :error ->
        load_chunk_async(position, from)
        {:noreply, storage}
    end
  end

  def handle_call(:get_stored, _from, storage) do
    {:reply, Map.keys(storage), storage}
  end

  @spec load_chunk_async(position, GenServer.from(), storage_config) :: any
  def load_chunk_async(position, receiver, config \\ @default_conf) do
    spawn_link(fn ->
      chunk_data = load_chunk(position, config)

      GenServer.reply(receiver, chunk_data)

      if chunk_data do
        Logger.debug(inspect([:chunk_loaded, position]))
        GenServer.cast(__MODULE__, {:store, position, chunk_data})
      end
    end)
  end

  @spec load_chunk(position, storage_config) :: chunk_data | nil
  def load_chunk(position, config \\ @default_conf) do
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
        Logger.warn(inspect([:chunk_load_error, position, err]))
        nil
    end
  end

  @spec save_chunk(position, chunk_data, storage_config) :: :ok | {:error, any}
  def save_chunk(position, chunk_data, config \\ @default_conf) do
    region_path = get_region_path(position, config)
    File.mkdir_p!(region_path)
    chunk_path = "#{region_path}/#{get_chunk_filename(position)}"

    status = File.open(chunk_path, [:write, :compressed], &IO.binwrite(&1, chunk_data))

    case status do
      {:ok, _} ->
        :ok

      {:error, err} ->
        Logger.warn(inspect([:chunk_save_error, position, err]))
        {:error, err}
    end
  end

  @spec get_chunk_filename(position) :: binary
  defp get_chunk_filename({cx, cz}) do
    "#{cx}_#{cz}.mccp"
  end

  @spec get_region_path(position, storage_config) :: binary
  defp get_region_path({cx, cz}, config) do
    # TODO -2 -> 0, should be -2 -> -1
    rx = div(cx, 32)
    rz = div(cz, 32)
    region_dir = "r_#{rx}_#{rz}"
    "#{config.storage_path}/#{region_dir}"
  end
end
