defmodule Coda.Providers.BlockProduced do
  use Architecture.LogProvider
  def resource_class, do: Coda.Resources.BlockProducer

  def log_filter do
    filter(do: "Successfully produced a new block: $breadcrumb")
  end
end
