defmodule MoreChunks.ClientSupervisor do
  use Supervisor

  def start_link() do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def get_clients() do
    Supervisor.which_children(__MODULE__)
    |> Enum.map(&elem(&1, 1))
  end

  def init(_config) do
    children = [
      worker(MoreChunks.Client, [], restart: :temporary)
    ]

    supervise(
      children,
      strategy: :simple_one_for_one
    )
  end
end
