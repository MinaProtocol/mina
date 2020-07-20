defmodule ArchitectureTests.StatisticTest do
  use ExUnit.Case, async: true

  doctest Architecture.Statistic

  import Architecture.Statistic

  test "statistic cycle detection" do
    # add each statistic here
    statistics = [Coda.Statistics.BlockProductionRate]
    check_cycle(statistics,MapSet.new)
  end
end
