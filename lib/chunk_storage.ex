defmodule ChunkFix.ChunkStorage do
  use GenServer

  ## Client API

  def start_link do
    GenServer.start_link(__MODULE__, :ok, [])
  end

  def store(position, packet_data) do
    # TODO timestamp
    GenServer.cast(__MODULE__, {:store, position, packet_data})
  end

  def lookup(position) do
    GenServer.call(__MODULE__, {:lookup, position})
  end

  ## Server Callbacks

  def init(:ok) do
    {:ok, %{}}
  end

  def terminate(reason, state) do
  end

  def handle_cast({:store, position, packet_data}, storage) do
    {:noreply, Map.put(storage, position, packet_data)}
  end

  def handle_call({:lookup, position}, _from, storage) do
    chunk = case Map.fetch(storage, position) do
      {:ok, chunk} -> chunk
      :error -> :nil # TODO get from disk
    end
    {:reply, chunk, storage}
  end

end
