# statistic_test.exs -- tests for the Architecture.Statistic module

alias Architecture.Statistic

# dummy statistics for cycle-checking
# N.B.: putting these inside a module causes, which would be neater,
#  causes problems with `has_behaviour?/2`

defmodule Stat0 do
  use Statistic

  @impl true
  def resources(_resource_db), do: :ok
  @impl true
  def init(_resource), do: :ok
  @impl true
  def update(_resource, _state), do: :ok
  @impl true
  def handle_message(_resource, _state, _, _log), do: :ok

  @impl true
  def providers, do: []
end

defmodule Stat1 do
  use Statistic

  @impl true
  def resources(_resource_db), do: :ok
  @impl true
  def init(_resource), do: :ok
  @impl true
  def update(_resource, _state), do: :ok
  @impl true
  def handle_message(_resource, _state, _, _log), do: :ok

  @impl true
  def providers, do: [Stat0]
end

defmodule Stat2 do
  use Statistic

  @impl true
  def resources(_resource_db), do: :ok
  @impl true
  def init(_resource), do: :ok
  @impl true
  def update(_resource, _state), do: :ok
  @impl true
  def handle_message(_resource, _state, _, _log), do: :ok

  @impl true
  def providers, do: [Stat0,Stat1]
end

defmodule Stat3 do
  use Statistic

  @impl true
  def resources(_resource_db), do: :ok
  @impl true
  def init(_resource), do: :ok
  @impl true
  def update(_resource, _state), do: :ok
  @impl true
  def handle_message(_resource, _state, _, _log), do: :ok

  @impl true
  def providers, do: [Stat4]
end

defmodule Stat4 do
  use Statistic

  @impl true
  def resources(_resource_db), do: :ok
  @impl true
  def init(_resource), do: :ok
  @impl true
  def update(_resource, _state), do: :ok
  @impl true
  def handle_message(_resource, _state, _, _log), do: :ok

  @impl true
  def providers, do: [Stat0,Stat1,Stat3]
end


defmodule ArchitectureTests.StatisticTest do
  use ExUnit.Case, async: true

  doctest Architecture.Statistic

  import Architecture.Statistic

  # tests with dummy statistics

  test "statistics with no cycle", _context do
    statistics = [Stat0,Stat1,Stat2]
    check_cycle(statistics,MapSet.new)
  end

  test "statistics with cycle", _context do
    try do
      # Stat3 depends on Stat4 depends on Stat3
      statistics = [Stat3]
      check_cycle(statistics,MapSet.new)
      assert(false)
    rescue
      _ -> :ok
    end
  end

  # test with real statistics

  test "real statistics check for cycles", _context do
    # add all statistics as roots here
    statistics = [Coda.Statistics.BlockProductionRate]
    check_cycle(statistics,MapSet.new)
  end

end
