defmodule Coda do
  @moduledoc "Coda network validation definitions."

  def project_id, do: Application.fetch_env!(:coda_validation, :project_id)
  def testnet, do: Application.fetch_env!(:coda_validation, :testnet)
  def region, do: Application.fetch_env!(:coda_validation, :region)
  def cluster, do: Application.fetch_env!(:coda_validation, :cluster)

end
