defmodule Coda.ResourceClassifier do
  @moduledoc """
  Resource classification for coda networks.

  It is a temporary flaw in the design that this is necessary, but I believe that this can be folded
  into the resource abstraction (with some thought).
  """

  alias Coda.Resources

  def classify_resource(message) do
    # TODO: make robust
    labels = message["labels"]

    if labels["k8s-pod/role"] == "block-producer" do
      Resources.BlockProducer.build(labels["k8s-pod/class"], labels["k8s-pod/id"])
    else
      Resources.CodaNode.build(labels["k8s-pods/name"])
    end
  end
end
