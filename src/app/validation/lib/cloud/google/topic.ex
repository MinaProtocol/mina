defmodule Cloud.Google.Topic do
  @moduledoc "Wrapper for interacting with GoogleCloud pub sub topics."

  alias GoogleApi.PubSub.V1, as: PubSub

  require Logger
  import Util
  import PubSub.Api.Projects

  @type t :: PubSub.Model.Topic.t()

  @spec get(Cloud.Google.pubsub_conn(), String.t()) :: t | nil
  def get(conn, name) do
    case pubsub_projects_topics_get(conn, Coda.project_id(), name) do
      {:ok, topic} ->
        topic

      {:error, error} ->
        Logger.warn(
          "got error looking up object from api; assuming that means it's not there for now -- #{
            inspect(error)
          }"
        )

        nil
    end
  end

  @spec create(Cloud.Google.pubsub_conn(), String.t()) :: t
  def create(conn, name) do
    case get(conn, name) do
      nil ->
        pubsub_projects_topics_create(conn, Coda.project_id(), name, body: %{})
        |> ok_or_error(Cloud.Google.ApiError, "failed to create topic")

      topic ->
        topic
    end
  end
end
