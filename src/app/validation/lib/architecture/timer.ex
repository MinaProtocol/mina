defmodule Architecture.Timer do
  @moduledoc "A generic timer process which can send :tick messages to a GenServer on an interval."

  require Logger

  defmodule TargetUnavailableError do
    defexception []

    def message(_), do: "timer target is unavailable"
  end

  @spec child_spec(get_target: function, update_interval: integer) :: Supervisor.child_spec()
  def child_spec(get_target: get_target, update_interval: update_interval) do
    %{
      id: __MODULE__,
      type: :worker,
      start: {__MODULE__, :start_link, [get_target, update_interval]},
      restart: :permanent,
      shutdown: :brutal_kill,
      modules: [__MODULE__]
    }
  end

  @spec start_link(function, integer) :: {:ok, pid}
  def start_link(get_target, update_interval) do
    pid = spawn_link(fn -> run(get_target, update_interval) end)
    {:ok, pid}
  end

  @spec run(function, integer) :: no_return
  def run(get_target, update_interval) do
    Logger.metadata(context: __MODULE__)
    Logger.info("fetching target #{inspect(get_target)}")

    case get_target.() do
      # if the target can't be found, crash and let our supervisor choose how to restart us to try again
      nil ->
        Logger.error("target is unavailable")
        raise TargetUnavailableError

      target_pid ->
        Logger.info("target found")
        tick_loop(target_pid, update_interval)
    end
  end

  @spec tick_loop(pid, integer) :: no_return
  def tick_loop(target_pid, update_interval) do
    :timer.sleep(update_interval)
    Logger.info("sending tick")
    :ok = GenServer.call(target_pid, :tick)
    tick_loop(target_pid, update_interval)
  end

  defmodule CoSupervisor do
    @moduledoc """
    A simple supervisor which can monitor another process alongside a timer.
    This is useful for wrapping the target process of a timer.
    """

    use Supervisor

    defmodule Params do
      @moduledoc "Supervisor parameters."

      use Class

      defclass(
        sidecar_mod: module,
        sidecar_arg: any,
        update_interval: pos_integer
      )
    end

    # # this type is missing from the standard library; corresponds with the return value of Supervisor.which_children
    # @type supervisor_child:: {Supervisor.term | :undefined, Supervisor.child | :restarting, :worker | :supervisor, :supervisor.modules()}

    # @spec is_sidecar_child(module, supervisor_child) :: boolean
    # def is_active_sidecar_child(sidecar_mod, {_id, _child, _type, modules}) do

    @spec find_sidecar(pid, module) :: pid | nil
    def find_sidecar(supervisor_pid, sidecar_mod) do
      sidecar_child_data =
        Supervisor.which_children(supervisor_pid)
        |> Enum.find(fn {_id, child_pid, _type, modules} ->
          Enum.member?(modules, sidecar_mod) and child_pid != :restarting
        end)

      case sidecar_child_data do
        nil -> nil
        {_id, sidecar_pid, _type, _modules} -> sidecar_pid
      end
    rescue
      e ->
        Logger.error("exception while getting target: #{inspect(e)}")
        nil
    end

    def start_link(params) do
      Supervisor.start_link(__MODULE__, params)
    end

    @impl true
    def init(%Params{} = params) do
      # in order to make the timer restart with the sidecar, but only restart the timer when it
      # fails, we choose the rest_for_one strategy and put the sidecar in front of the timer
      strategy = :rest_for_one

      supervisor_pid = self()

      children = [
        {params.sidecar_mod, params.sidecar_arg},
        {Architecture.Timer,
         [
           get_target: fn -> find_sidecar(supervisor_pid, params.sidecar_mod) end,
           update_interval: params.update_interval
         ]}
      ]

      Supervisor.init(children, strategy: strategy)
    end
  end
end
