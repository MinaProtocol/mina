defmodule Coda.Statistics.BlockProductionRate do
  @moduledoc "A scalar stastics that monitors the block production rate of a block producer"

  alias Architecture.ResourceSet
  alias Architecture.Statistic

  use Statistic

  @impl true
  def log_providers, do: [Coda.Providers.BlockProduced]
  @impl true
  def resources(resource_db),
    do: ResourceSet.select(resource_db, Coda.Resources.BlockProducer)

  defmodule State do
    @moduledoc "State for Coda.Statistics.BlockProductionRate"

    use Class

    defclass(
      start_time: Time.t(),
      elapsed_time: Time.t(),
      last_updated: Time.t(),
      blocks_produced: pos_integer()
    )
  end

  @type state :: State.t()

  @impl true
  def init(_resource) do
    start_time = Time.utc_now()
    {:ok, zero_time} = Time.new(0, 0, 0, 0)

    %State{
      start_time: start_time,
      elapsed_time: zero_time,
      last_updated: start_time,
      blocks_produced: 0
    }
  end

  defp update_time(state) do
    now = Time.utc_now()
    ms_since_last_update = Time.diff(now, state.last_updated, :millisecond)
    elapsed_time = Time.add(state.elapsed_time, ms_since_last_update, :millisecond)
    %State{state | last_updated: now, elapsed_time: elapsed_time}
  end

  @impl true
  def update(_resource, state), do: update_time(state)

  @impl true
  def handle_log(_resource, state, Coda.Providers.BlockProduced, _log) do
    %State{state | blocks_produced: state.blocks_produced + 1}
  end
end
