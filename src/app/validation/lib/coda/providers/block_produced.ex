defmodule Coda.Providers.BlockProduced do
  @moduledoc "Log provider for block production."

  use Architecture.LogProvider

  def resource_class, do: Coda.Resources.BlockProducer

  def log_filter do
    filter(do: "Successfully produced a new block: $breadcrumb")
  end
end
