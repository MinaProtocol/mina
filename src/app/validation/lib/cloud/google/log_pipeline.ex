defmodule Cloud.Google.LogPipeline do
  @moduledoc """
  A log pipelines consists of 3 cloud resources representing a data pipeline of logs to consume from
  Google StackDriver. A log pipeline contains a pub sub topic, a subscription to that topic, and a
  log sink which is feeding messages into the pub sub topic.
  """

  alias Cloud.Google.LogSink
  alias Cloud.Google.Subscription
  alias Cloud.Google.Topic

  use Class

  defclass(
    name: String.t(),
    topic: Topic.t(),
    subscription: Subscription.t(),
    log_sink: LogSink.t()
  )

  @spec create(Cloud.Google.pubsub_conn(), Cloud.Google.logging_conn(), String.t(), String.t()) ::
          t
  def create(pubsub_conn, logging_conn, name, filter) do
    topic = Topic.create(pubsub_conn, name)
    subscription = Subscription.create(pubsub_conn, name, topic)
    log_sink = LogSink.create(logging_conn, name, topic, filter)

    %__MODULE__{
      name: name,
      topic: topic,
      subscription: subscription,
      log_sink: log_sink
    }
  end
end
