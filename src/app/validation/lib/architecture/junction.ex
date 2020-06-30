defmodule Architecture.Junction do
  @moduledoc """
  Mixin for defining junctions. Junctions are a pattern around `Registry`s which provide a
  highly-parallel pub/sub system.
  """

  defmacro __using__(_params) do
    quote do
      def child_spec do
        Registry.child_spec(
          keys: :duplicate,
          name: __MODULE__,
          partitions: System.schedulers_online()
        )
      end

      def subscribe(key) do
        Registry.register(__MODULE__, key, [])
      end

      def broadcast(key, msg) do
        Registry.dispatch(__MODULE__, key, fn entries ->
          msg = {:subscription, key, msg}
          Enum.each(entries, fn {pid, _} -> GenServer.cast(pid, msg) end)
        end)
      end
    end
  end
end
