defmodule Coda.Validations.Configuration do
  @moduledoc """
  Configuration parameters used by the validations
  TODO: Read these parameters from a file at application startup
  """

  # in milliseconds
  def slot_time, do: 3 * 60 * 1000

  # in milliseconds: 20 * 60 * 1000
  def grace_window(_state), do: Time.from_iso8601!("00:20:00")

  def acceptable_margin, do: 0.05

  # dummy values, not based on actual stake
  def whale_win_rates, do: [0.15,0.20,0.05,0.08,0.3]

end
