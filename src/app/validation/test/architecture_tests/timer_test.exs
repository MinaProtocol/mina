defmodule ArchitectureTests.TimerTest do
  use ExUnit.Case, async: true
  doctest Architecture.Timer

  alias Architecture.Timer

  defmodule TickRecipient do
    use GenServer

    def start_link([expected_ticks, notify_pid]) do
      GenServer.start_link(
        __MODULE__,
        {expected_ticks, notify_pid}
      )
    end

    def init(args), do: {:ok, args}

    def handle_call(:tick, _caller, {expected_ticks, notify_pid}) do
      if expected_ticks == 0 do
        send(notify_pid, :success)
      end

      {:reply, :ok, {expected_ticks - 1, notify_pid}}
    end
  end

  test "co-supervision test" do
    update_interval = 1_000
    num_ticks = 5
    timeout = update_interval * (num_ticks + 2)

    {:ok, pid} =
      Timer.CoSupervisor.start_link(%Timer.CoSupervisor.Params{
        sidecar_mod: TickRecipient,
        sidecar_arg: [num_ticks, self()],
        update_interval: update_interval
      })

    assert_receive(:success, timeout)
    :ok = Supervisor.stop(pid)
  end
end
