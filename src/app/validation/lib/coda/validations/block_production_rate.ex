defmodule Coda.Validations.BlockProductionRate do
  @moduledoc """
  Validates that a block producer's block production rate matches is within an acceptable_margin of
  the expected rate.
  """

  use Architecture.Validation

  import Coda.Validations.Configuration

  require Logger

  @impl true
  def statistic, do: Coda.Statistics.BlockProductionRate

  @impl true
  def validate({Coda.Statistics.BlockProductionRate,resource}, state) do
    # implication

    if Time.compare(state.elapsed_time,grace_window(state)) == :lt do
      :valid
    else
      tm = state.elapsed_time
      elapsed_sec = tm.hour * 60 * 60 + tm.minute * 60 + tm.second
      slots_elapsed = elapsed_sec / slot_time()

      slot_production_ratio = state.blocks_produced / slots_elapsed

      # putting the call to acceptable_margin() here make dialyzer happy
      margin = acceptable_margin()

      cond do
        slot_production_ratio >= 1 ->
          {:invalid, "unexpected, slot production ratio is 1 or greater"}

        slot_production_ratio < resource.expected_win_rate - margin ->
          {:invalid, "not producing enough blocks"}

        slot_production_ratio > resource.expected_win_rate + margin ->
          {:invalid, "producing more blocks than expected"}

        true ->
          :valid
      end
    end
  end
end
