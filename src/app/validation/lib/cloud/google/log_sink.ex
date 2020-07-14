defmodule Cloud.Google.LogSink do
  @moduledoc "Wrapper for interacting with GoogleCloud logging sinks."

  import Util
  alias GoogleApi.Logging.V2, as: Logging
  import Logging.Api.Sinks
  alias Logging.Model.LogSink

  @type t :: LogSink.t()

  # only supports creation, currently
  @spec create(Cloud.Google.logging_conn(), String.t(), Cloud.Google.Topic.t(), String.t()) :: t
  @spec create(
          Cloud.Google.logging_conn(),
          String.t(),
          Cloud.Google.Topic.t(),
          String.t(),
          boolean
        ) ::
          t
  def create(conn, name, topic, filter, already_attempted \\ false) do
    sink_destination = "pubsub.googleapis.com/#{topic.name}"

    sink_body = %LogSink{
      description: "validation log sink",
      name: name,
      destination: sink_destination,
      filter: filter
    }

    case logging_sinks_create(conn, "projects", Coda.project_id(), body: sink_body) do
      {:ok, sink} ->
        sink

      {:error, env} ->
        json = Jason.decode!(env.body)

        if not already_attempted and json["error"]["status"] == "ALREADY_EXISTS" do
          IO.puts("log sink #{name} already existed, destroying and recreating")

          logging_sinks_delete(conn, "projects", Coda.project_id(), name)
          |> ok_or_error(Cloud.Google.ApiError, "failed to create sink")

          create(conn, name, topic, filter, true)
        else
          raise Cloud.Google.ApiError,
            error_message: "failed to create sink",
            erorr: json["error"]
        end

        # |> ok_or_error(Cloud.Google.ApiError, "failed to create sink")
    end
  end
end
