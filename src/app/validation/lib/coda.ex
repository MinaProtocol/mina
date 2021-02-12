defmodule Coda do
  @moduledoc "Mina network validation definitions."

  def project_id, do: Application.fetch_env!(:mina_validation, :project_id)
  def testnet, do: Application.fetch_env!(:mina_validation, :testnet)
  def region, do: Application.fetch_env!(:mina_validation, :region)
  def cluster, do: Application.fetch_env!(:mina_validation, :cluster)

end
