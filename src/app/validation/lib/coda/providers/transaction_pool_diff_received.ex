defmodule Coda.Providers.TransactionPoolDiffReceived do
  use Architecture.LogProvider
  def resource_class, do: Coda.Resources.BlockProducer

  def log_filter do
    filter(do: "Received transaction-pool diff $txns from $sender")
  end
end
