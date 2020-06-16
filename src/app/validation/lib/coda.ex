defmodule Coda do
  def project_id, do: Application.fetch_env!(:coda_validation, :project_id)
end
