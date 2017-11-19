defmodule MoreChunks.Metrics do
  use GenServer

  require Logger

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @ignored_metrics MapSet.new(
                     Application.get_env(:morechunks, :ignored_metrics, [
                       :chunk_loaded,
                       :chunk_lookup_hit,
                       :chunk_lookup_miss,
                       :chunk_update,
                       :sent_chunk,
                       :user_contributed_chunk
                     ])
                   )

  def cast(metric_list) do
    unless @ignored_metrics |> MapSet.member?(hd(metric_list)) do
      GenServer.cast(__MODULE__, {:metric, metric_list})
    end
  end

  def cast(metric_list, remote) do
    unless @ignored_metrics |> MapSet.member?(hd(metric_list)) do
      GenServer.cast(__MODULE__, {:metric, metric_list, remote})
    end
  end

  ## Server Callbacks

  def init(_args) do
    cast([:start_module, __MODULE__])
    {:ok, %{}}
  end

  ###### internal

  def handle_cast({:metric, [:start_module, module | args]}, state) do
    Logger.info("Starting #{module}, args: #{inspect(args)}")
    {:noreply, state}
  end

  ###### chunk storage

  def handle_cast({:metric, [:chunk_creation, position, packet_size]}, state) do
    pos = inspect(MoreChunks.nice_pos(position))
    Logger.debug("Storing new chunk at #{pos}, size: #{inspect(packet_size)}")

    {:noreply, state}
  end

  def handle_cast({:metric, [:chunk_load_error, position, error]}, state) do
    pos = inspect(MoreChunks.nice_pos(position))
    Logger.debug("Loading chunk at #{pos} failed: #{inspect(error)}")

    {:noreply, state}
  end

  ###### protocol

  def handle_cast({:metric, _remote, [:user_request, positions_long]}, state) do
    positions = Enum.map(positions_long, &MoreChunks.nice_pos/1)
    Logger.debug("Received request for #{length(positions)} chunks at #{positions}")

    {:noreply, state}
  end

  def handle_cast({:metric, _remote, [:user_set_chunks_per_second, chunks_per_second]}, state) do
    Logger.debug("Received chunks_per_second: #{chunks_per_second}")
    {:noreply, state}
  end

  def handle_cast({:metric, _remote, [:user_info_unknown, payload]}, state) do
    Logger.warn("Received unknown info: #{payload}")
    {:noreply, state}
  end

  ###### user connection status

  def handle_cast({:metric, [:user_connected], remote}, state) do
    Logger.debug("New connection from #{inspect(remote)}")
    {:noreply, state}
  end

  def handle_cast({:metric, [:user_closed], remote}, state) do
    Logger.debug("Connection closed at #{inspect(remote)}")
    {:noreply, state}
  end

  def handle_cast({:metric, [:handler_error, error], remote}, state) do
    Logger.debug("Error handling packet from #{inspect(remote)}: #{inspect(error)}")
    {:noreply, state}
  end

  ###### unknown metrics

  def handle_cast({:metric, metric_list}, state) do
    Logger.warn("Unknown metric #{inspect(metric_list)}")
    {:noreply, state}
  end

  def handle_cast({:metric, metric_list, remote}, state) do
    Logger.warn("Unknown client metric #{inspect(metric_list)} for #{inspect(remote)}")
    {:noreply, state}
  end
end
