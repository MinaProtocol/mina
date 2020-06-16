defmodule Architecture.Validation do
  require Logger
  alias Architecture.AlertServer
  alias Architecture.Resource
  alias Architecture.ResourceDatabase
  alias Architecture.Statistic
  alias Architecture.Validation

  @callback statistic :: module
  @callback validate(Resource.t(), module, any) :: :valid | {:invalid, String.t()}

  defmacro __using__(_params) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  defmodule Spec do
    use Class

    defclass(
      validation: module,
      resource_db: ResourceDatabase.t()
    )
  end

  defmodule Broker do
    use GenServer

    def child_spec(mod, resource) do
      %{
        # TEMP HACK: existence of resource.id is an unreasonable assumption
        id: "#{mod}:#{resource.__struct__}:#{resource.name}",
        type: :worker,
        start: {__MODULE__, :start_link, [mod, resource]},
        restart: :permanent,
        modules: [__MODULE__, mod]
      }
    end

    def start_link(mod, resource) do
      GenServer.start_link(
        __MODULE__,
        {mod, resource}
      )
    end

    @impl true
    def init({mod, resource}) do
      Logger.metadata(context: __MODULE__)
      Logger.info("initializing")
      # IO.puts("here...#{Enum.member?(Process.registered(), Architecture.Statistic.Junction)}")

      # TODO: pluralize
      # validations = 
      # Enum.map(...)
      {:ok, {mod, resource}, {:continue, nil}}
    end

    @impl true
    def handle_continue(nil, {mod, resource}) do
      Logger.info("subscribing to #{mod.statistic()}")
      Statistic.Junction.subscribe(mod.statistic(), resource)
      {:noreply, {mod, resource}}
    end

    @impl true
    def handle_cast({:subscription, statistic, state}, {mod, resource}) do
      Logger.info("received new state from #{statistic}")

      case mod.validate(resource, state) do
        :valid ->
          Logger.info("validation successful")
          {:noreply, {mod, resource}}

        {:invalid, reason} ->
          Logger.info("validation failed: #{reason}")
          AlertServer.validation_error(mod, resource, reason)
          {:noreply, {mod, resource}}
      end
    end
  end

  defmodule MainSupervisor do
    use Supervisor

    def start_link(validation_specs) do
      Supervisor.start_link(__MODULE__, validation_specs, name: __MODULE__)
    end

    @impl true
    def init(validation_specs) do
      # children = Validation.Spec.child_specs(validations_spec)
      children =
        Enum.flat_map(validation_specs, fn spec ->
          ResourceDatabase.all_resources(spec.resource_db)
          |> Enum.map(&Validation.Broker.child_spec(spec.validation, &1))
        end)

      Supervisor.init(children, strategy: :one_for_one)
    end
  end
end
