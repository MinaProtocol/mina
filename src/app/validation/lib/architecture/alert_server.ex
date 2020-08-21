defmodule Architecture.AlertServer do
  @moduledoc """
  One day, this will be the AlertServer which manages alerts fromv validations. For now, it's a
  noop.
  """

  def validation_error(_, _, _) do
    IO.puts("woopsie")
  end
end
