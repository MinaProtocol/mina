# TODO: fully separate this from the rest of the project
# currently, it depends on Coda directly for configuration, and log providers depend on this directly

defmodule Cloud.Google do
  @moduledoc "Google Cloud interface."

  alias GoogleApi.Logging.V2, as: Logging
  alias GoogleApi.PubSub.V1, as: PubSub

  @type pubsub_conn :: PubSub.Connection.t()
  @type logging_conn :: Logging.Connection.t()

  defmodule ApiError do
    defexception [:message, :error]

    def message(%__MODULE__{message: message, error: error}) do
      "#{message}: #{inspect(error)}"
    end
  end

  defmodule Connections do
    @moduledoc "Collection of connections for communicating with the Google Cloud API"

    use Class

    defclass(
      pubsub: Cloud.Google.pubsub_conn(),
      logging: Cloud.Google.logging_conn()
    )
  end

  @spec connect :: Connections.t()
  def connect do
    {:ok, token} = Goth.Token.for_scope("https://www.googleapis.com/auth/cloud-platform")

    %Connections{
      pubsub: PubSub.Connection.new(token.token),
      logging: Logging.Connection.new(token.token)
    }
  end
end
