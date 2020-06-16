defmodule Coda.Resources.CodaNode do
  @moduledoc "CodaNode resource definition."

  use Architecture.Resource

  defresource(name: String.t())

  @spec build(String.t()) :: t
  def build(name), do: %__MODULE__{name: name}

  @impl true
  def global_filter do
    filter do
      resource.labels.container_name == "coda"
    end
  end

  @impl true
  def local_filter(%__MODULE__{name: name}) do
    filter(do: labels["k8s-pod/app"] == "#{name}")
  end
end
