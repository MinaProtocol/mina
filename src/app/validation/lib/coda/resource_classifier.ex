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
      app = labels["k8s-pod/app"] # e.g., whale-block-producer-4
      id = String.split(app,"-") |> List.last |> String.to_integer
      win_rate = Enum.fetch!(Coda.Validations.Configuration.whale_win_rates,id - 1)
      # class, id, expected_win_rate
      Resources.BlockProducer.build(labels["k8s-pod/class"], id, win_rate)
    else
      Resources.CodaNode.build(labels["k8s-pods/name"])
    end
  end
end
