defmodule Architecture.LogProvider do
  @moduledoc "Behaviour for log providers."

  alias Architecture.ResourceSet
  alias Cloud.Google.Subscription

  @type t :: module
  # TODO
  @type log :: any

  @callback resource_class() :: module()
  @callback log_filter() :: Architecture.LogFilter.t()

  defmacro __using__(_params) do
    quote do
      @behaviour unquote(__MODULE__)
      import Architecture.LogFilter.Language
      require Architecture.LogFilter.Language
    end
  end

  def log_filter(log_provider, resource_db) do
    resource_filter = ResourceSet.filter(resource_db)
    Architecture.LogFilter.adjoin(resource_filter, log_provider.log_filter())
  end

  defmodule Junction do
    @moduledoc "Junction for logs."

    use Architecture.Junction

    def subscribe(log_provider, resource), do: subscribe({log_provider, resource})
    def broadcast(log_provider, resource, msg), do: broadcast({log_provider, resource}, msg)
  end

  defmodule Spec do
    @moduledoc "Specification of a log provider to execute."

    use Class

    defclass(
      conn: Cloud.Google.pubsub_conn(),
      subscription: Subscription.t(),
      log_provider: module
    )
  end

  defmodule Broker do
    @moduledoc "Interpreter and message broker for executing log providers."

    # Each provider has 1 sink pub/sub pipeline associated with it. Provider ingests gcloud
    # subscriptions and forwards to junction if the associated resource exists in the resource
    # set.
    require Logger
    alias Architecture.LogProvider

    @spec child_spec(LogProvider.Spec.t()) :: Supervisor.child_spec()
    def child_spec(%LogProvider.Spec{} = spec) do
      %{
        id: __MODULE__,
        type: :worker,
        start: {__MODULE__, :start_link, [spec]},
        restart: :permanent,
        modules: [__MODULE__, spec.log_provider]
      }
    end

    @spec start_link(LogProvider.Spec.t()) :: {:ok, pid}
    def start_link(spec) do
      {:ok, spawn_link(fn -> init(spec) end)}
    end

    @spec init(LogProvider.Spec.t()) :: no_return
    def init(spec) do
      Logger.metadata(context: __MODULE__)
      Process.register(self(), String.to_atom("#{__MODULE__}:#{spec.log_provider}"))
      run(spec)
    end

    @spec run(LogProvider.Spec.t()) :: nil
    def run(spec) do
      Subscription.pull_and_process(spec.conn, spec.subscription, &handle_message/1)
      run(spec)
    end

    # TODO: properly define message schema as a type
    @spec handle_message(map) :: :ok
    def handle_message(message) do
      resource =
        try do
          # TODO: implement dynamic resource classification
          Coda.ResourceClassifier.classify_resource(message)
        rescue
          e ->
            Logger.error("failed to classify resource")
            reraise e, __STACKTRACE__
        end

      LogProvider.Junction.broadcast(__MODULE__, resource, message)
    end
  end

  defmodule MainSupervisor do
    @moduledoc "Main supervisor for spawning and monitoring log providers."

    alias Architecture.LogProvider

    use Supervisor

    def start_link(log_provider_specs) do
      Supervisor.start_link(__MODULE__, log_provider_specs, name: __MODULE__)
    end

    @impl true
    def init(log_provider_specs) do
      children = [
        LogProvider.Junction.child_spec()
        | Enum.map(log_provider_specs, &broker_child_spec/1)
      ]

      Supervisor.init(children, strategy: :one_for_one)
    end

    defp broker_child_spec(spec) do
      Supervisor.child_spec(
        {LogProvider.Broker, spec},
        id: "LogProvider.Broker:#{spec.log_provider}"
      )
    end
  end
end
