defmodule Architecture.Statistic do
  @moduledoc "Behaviour for statistics."

  alias Architecture.LogProvider
  alias Architecture.Resource
  alias Architecture.ResourceSet
  alias Architecture.Timer

  @type t :: module
  @type message :: any

  @callback providers :: [module] # log providers or other statistics
  @callback resources(ResourceSet.t()) :: ResourceSet.t()
  @callback init(Resource.t()) :: struct
  @callback update(Resource.t(), state) :: state when state: struct
  @callback handle_message(Resource.t(), state, t(), message()) :: state
            when state: struct

  # a statistic can depend on a statistic provider, so cycles are possible
  @spec check_cycle([module],MapSet.t()) :: :ok
  def check_cycle(providers,seen) do
    Enum.each(providers,
      fn prov ->
	if MapSet.member?(seen,prov) do
          raise "Found a Statistics provider cycle containing #{prov}"
        end
	# a Log_provider has no provider dependencies
	if Util.has_behaviour?(prov,Architecture.Statistic) do
	  check_cycle(prov.providers,MapSet.put(seen,prov))
	end
      end)
    :ok
  end

  defmacro __using__(_params) do
    quote do
      @behaviour unquote(__MODULE__)
    end
  end

  defmodule Junction do
    @moduledoc "Junction for statistic states."

    use Architecture.Junction

    def subscribe(statistic, resource), do: subscribe({statistic, resource})
    def broadcast(statistic, resource, msg), do: broadcast({statistic, resource}, msg)
  end

  defmodule Spec do
    @moduledoc "Specification of a statistic to execute."

    use Class

    defclass(
      statistic: module,
      resource_db: ResourceSet.t()
    )
  end

  defmodule Broker do
    @moduledoc "Interpreter and message broker for executing statistics."

    alias Architecture.Statistic
    require Logger

    defmodule Params do
      @moduledoc "Statistic broker parameters."

      defstruct [:mod, :resource]
    end

    use GenServer

    def start_link(params) do
      Logger.info("starting #{__MODULE__} for #{params.resource.name}")

      GenServer.start_link(
        __MODULE__,
        params,
        name: String.to_atom("#{__MODULE__}:#{params.mod}:#{params.resource.name}")
      )
    end

    def update(server), do: GenServer.call(server, :update)

    @impl true
    def init(params) do
      Logger.metadata(context: __MODULE__)
      Logger.info("subscribing to providers", process_module: __MODULE__)
      Enum.each(params.mod.providers(),
	fn provider ->
	  cond do
	    Util.has_behaviour?(provider,Architecture.Log_provider) ->
	      &LogProvider.Junction.subscribe(&1, params.resource)
	    Util.has_behaviour?(provider,Architecture.Statistic) ->
	      &Statistic.Junction.subscribe(&1, params.resource)
	    true ->
	      raise "#{provider} must be an instance of either Log_provider or Statistic"
	  end
	end)
      state = params.mod.init(params.resource)
      {:ok, {params,state}}
    end

    @impl true
    def handle_cast({:subscription, provider, message}, {params, state}) do
      state = params.mod.handle_message(params.resource, state, provider, message)
      Statistic.Junction.broadcast(__MODULE__, params.resource, state)
      {:noreply, {params, state}}
    end

    @impl true
    def handle_call(:tick, _from, {params, state}) do
      state = params.mod.update(params.resource, state)
      Statistic.Junction.broadcast(__MODULE__, state)
      {:reply, :ok, {params, state}}
    end
  end

  defmodule MainSupervisor do
    @moduledoc "Main supervisor for spawning and monitoring statistics."

    alias Architecture.Statistic

    use Supervisor

    # TODO: make configurable per statistic
    @default_update_interval 20_000

    def start_link(statistics_spec) do
      Supervisor.start_link(__MODULE__, statistics_spec, name: __MODULE__)
    end

    def init(stat_specs) do
      # Logger.metadata(context: __MODULE__)

      all_broker_child_specs = Enum.flat_map(stat_specs, &broker_child_specs/1)
      children = [Statistic.Junction.child_spec() | all_broker_child_specs]

      Supervisor.init(children, strategy: :one_for_one)
    end

    @spec broker_child_specs(Statistic.Spec.t()) :: [Supervisor.child_spec()]
    def broker_child_specs(%Statistic.Spec{} = stat_spec) do
      if not Util.has_behaviour?(stat_spec.statistic, Architecture.Statistic) do
        raise "#{inspect(stat_spec.statistic)} must be a Statistic"
      end

      stat_spec.statistic.resources(stat_spec.resource_db)
      |> ResourceSet.all_resources()
      |> Enum.map(fn resource ->
        # We construct the following supervision tree for each statistic we compute:
        #
        #                      Timer.CoSupervisor
        #                    /                    \
        #             Statistic.Broker           Timer
        #    (executing stat_spec.statistic)

        # TEMP HACK: existence of resource.id is an unreasonable assumption

        server_params = %Statistic.Broker.Params{
          mod: stat_spec.statistic,
          resource: resource
        }

        supervisor_params = %Timer.CoSupervisor.Params{
          sidecar_mod: Statistic.Broker,
          sidecar_arg: server_params,
          update_interval: @default_update_interval
        }

        broker_id = "Statistic.Broker:#{stat_spec.statistic}:#{resource.name}"
        timer_cosup_id = "Timer.CoSupervisor:#{broker_id}"

        Supervisor.child_spec(
          {Timer.CoSupervisor, supervisor_params},
          id: timer_cosup_id
        )
      end)
    end
  end
end
