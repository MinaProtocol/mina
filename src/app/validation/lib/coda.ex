defmodule Coda do
  @moduledoc "Coda network validation definitions."

  def project_id, do: Application.fetch_env!(:coda_validation, :project_id)
end
