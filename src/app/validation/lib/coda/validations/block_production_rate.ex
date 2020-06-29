defmodule Coda.Validations.BlockProductionRate do
  @moduledoc """
  Validates that a block producer's block production rate matches is within an acceptable_margin of
  the expected rate.
  """

  use Architecture.Validation

  # TODO
  defp slot_time, do: 3 * 60 * 1000
  defp grace_window(_state), do: 20 * 60 * 1000
  defp acceptable_margin, do: 0.05

  defp win_rate(_), do: raise("TODO")

  @impl true
  def statistic, do: Coda.Statistics.BlockProductionRate

  @impl true
  def validate(_resource, Coda.Statistics.BlockProductionRate, state) do
    # implication
    if state.elapsed_time < grace_window(state) do
      :valid
    else
      slots_elapsed = state.elapsed_ns / slot_time()
      slot_production_ratio = state.blocks_produced / slots_elapsed

      # putting the call to acceptable_margin() here make dialyzer happy
      margin = acceptable_margin()

      cond do
        slot_production_ratio >= 1 ->
          {:invalid, "wow, something is *really* broken"}

        slot_production_ratio < win_rate(state.stake_ratio) - margin ->
          {:invalid, "not producing enough blocks"}

        slot_production_ratio > win_rate(state.stake_ratio) + margin ->
          {:invalid, "producing more blocks than expected"}

        true ->
          :valid
      end
    end
  end
end
