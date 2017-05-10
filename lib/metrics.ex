defmodule ChunkFix.Metrics do
  use GenServer

  require Logger

  ## Client API

  def start_link() do
    GenServer.start_link(__MODULE__, [], [name: __MODULE__])
  end

  def chunk_creation(position, packet_size) do
    GenServer.cast(__MODULE__, {:chunk_creation, position, packet_size})
  end

  def chunk_update(position, packet_size, old_packet_size) do
    GenServer.cast(__MODULE__, {:chunk_update, position, packet_size, old_packet_size})
  end

  def chunk_lookup_hit(position) do
    GenServer.cast(__MODULE__, {:chunk_lookup_hit, position})
  end

  def chunk_lookup_miss(position) do
    GenServer.cast(__MODULE__, {:chunk_lookup_miss, position})
  end

  def user_contributed_chunk(remote, pos_long, packet_size) do
    GenServer.cast(__MODULE__, {:user_contributed_chunk, remote, pos_long, packet_size})
  end

  def sent_chunk(remote, pos_long) do
    GenServer.cast(__MODULE__, {:sent_chunk, remote, pos_long})
  end

  def user_request(remote, positions) do
    GenServer.cast(__MODULE__, {:user_request, remote, positions})
  end

  def user_info(remote, payload) do
    GenServer.cast(__MODULE__, {:user_info, remote, payload})
  end

  def user_connected(remote) do
    GenServer.cast(__MODULE__, {:user_connected, remote})
  end

  def user_closed(remote, result) do
    GenServer.cast(__MODULE__, {:user_closed, remote, result})
  end

  def user_finished(remote) do
    GenServer.cast(__MODULE__, {:user_finished, remote})
  end

  def handler_error(remote, error) do
    GenServer.cast(__MODULE__, {:handler_error, remote, error})
  end

  ## Server Callbacks

  def init(args) do
    Logger.info "Starting Metrics, args: #{inspect args}"
    {:ok, %{
    }}
  end

  def terminate(reason, _state) do
    Logger.warn "Terminating Metrics, reason: #{inspect reason}"
  end

  ###### chunk storage

  def handle_cast({:chunk_creation, position, packet_size}, state) do
    Logger.debug "Storing new chunk at #{inspect ChunkFix.nice_pos position}, size: #{inspect packet_size}"
    {:noreply, state}
  end

  def handle_cast({:chunk_update, position, packet_size, old_packet_size}, state) do
    if packet_size != old_packet_size do
      Logger.debug "Replacing chunk at #{inspect ChunkFix.nice_pos position}, new size: #{inspect packet_size}, was: #{inspect old_packet_size}"
    else
      Logger.debug "Replacing chunk at #{inspect ChunkFix.nice_pos position}, same size: #{inspect packet_size}"
    end
    {:noreply, state}
  end

  def handle_cast({:chunk_lookup_hit, position}, state) do
    {:noreply, state}
  end

  def handle_cast({:chunk_lookup_miss, position}, state) do
    {:noreply, state}
  end

  ###### protocol

  def handle_cast({:user_contributed_chunk, remote, pos_long, packet_size}, state) do
    {:noreply, state}
  end

  def handle_cast({:sent_chunk, remote, pos_long}, state) do
    {:noreply, state}
  end

  def handle_cast({:user_request, remote, positions}, state) do
    Logger.debug("received request for #{length positions} chunks from #{inspect remote}")
    {:noreply, state}
  end

  def handle_cast({:user_info, remote, payload}, state) do
    Logger.info("received info: #{payload}")
    {:noreply, state}
  end

  ###### user connection status

  def handle_cast({:user_connected, remote}, state) do
    Logger.debug "New connection from #{inspect remote}"
    {:noreply, state}
  end

  def handle_cast({:user_closed, remote, result}, state) do
    Logger.debug "Connection closed at #{inspect remote} with #{inspect result}"
    {:noreply, state}
  end

  def handle_cast({:user_finished, remote}, state) do
    {:noreply, state}
  end

  def handle_cast({:handler_error, remote, error}, state) do
    Logger.debug "error handling packet from #{inspect remote}: #{inspect error}"
    {:noreply, state}
  end

end
