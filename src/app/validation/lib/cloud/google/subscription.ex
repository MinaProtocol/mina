defmodule Cloud.Google.Subscription do
  @moduledoc "Wrapper for interacting with GoogleCloud pub sub subscriptions."

  alias GoogleApi.PubSub.V1, as: PubSub
  alias PubSub.Model.AcknowledgeRequest
  alias PubSub.Model.ExpirationPolicy
  alias PubSub.Model.PullRequest
  alias PubSub.Model.PullResponse
  alias PubSub.Model.Subscription

  import Util
  import PubSub.Api.Projects
  require Logger

  @type t :: Subscription.t()

  @spec short_name(t) :: String.t()
  def short_name(subscription) do
    subscription.name |> String.split("/") |> List.last()
  end

  @spec get(Cloud.Google.pubsub_conn(), String.t()) :: t | nil
  def get(conn, name) do
    pubsub_projects_subscriptions_get(conn, Coda.project_id(), name)
    |> ok_or_nil()
  end

  @spec create(Cloud.Google.pubsub_conn(), String.t(), Cloud.Google.Topic.t()) :: t
  def create(conn, name, topic) do
    case get(conn, name) do
      nil ->
        subscription_body = %Subscription{
          topic: topic.name,
          messageRetentionDuration: "3600s",
          # 1 day
          expirationPolicy: %ExpirationPolicy{ttl: "86400s"}
        }

        pubsub_projects_subscriptions_create(conn, Coda.project_id(), name,
          body: subscription_body
        )
        |> ok_or_error(Cloud.Google.ApiError, "failed to create subscription")

      subscription ->
        subscription
    end
  end

  @spec pull_raw(Cloud.Google.pubsub_conn(), t) :: PullResponse.t()
  def pull_raw(conn, subscription) do
    pull_request = %PullRequest{maxMessages: 20}

    Logger.info("pulling subscription #{short_name(subscription)}")

    pubsub_projects_subscriptions_pull(
      conn,
      Coda.project_id(),
      short_name(subscription),
      body: pull_request
    )
    |> ok_or_error(Cloud.Google.ApiError, "failed to pull subscription")
  end

  @spec acknowledge(Cloud.Google.pubsub_conn(), t, PullResponse.t() | [String.t()]) :: any
  def acknowledge(conn, subscription, %PullResponse{receivedMessages: messages}) do
    acknowledge(conn, subscription, Enum.map(messages, & &1.ackId))
  end

  def acknowledge(conn, subscription, ack_ids) when is_list(ack_ids) do
    ack_request = %AcknowledgeRequest{ackIds: ack_ids}

    pubsub_projects_subscriptions_acknowledge(
      conn,
      Coda.project_id(),
      short_name(subscription),
      body: ack_request
    )
    |> ok_or_error(Cloud.Google.ApiError, "failed to acknowledge subscription messages")
  end

  # TODO: allow this to send intermediate acknowledgements and handle failures in f?
  @spec pull_and_process(Cloud.Google.pubsub_conn(), t, function) :: no_return
  def pull_and_process(conn, subscription, f) do
    response = pull_raw(conn, subscription)

    if response.receivedMessages != nil do
      count = length(response.receivedMessages)
      Logger.info("beginning to process #{count} messages")

      ack_ids =
        Enum.map(response.receivedMessages, fn received_message ->
          message_data =
            received_message.message.data
            |> Base.decode64!()
            |> Jason.decode!()

          f.(message_data)
          received_message.ackId
        end)

      acknowledge(conn, subscription, ack_ids)
      Logger.info("processed and acknowledged #{count} messages")
    else
      Logger.info("no messages received: #{inspect(response)}")
    end
  end
end
