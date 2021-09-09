defmodule PrettyConsoleLog do
  @moduledoc """
  Provides an alternative message format for elixir's `Logger`. Processes in the system may register
  a `:context` metadata value which will be logged along with logs from that process.
  """

  defp format_pid(pid) do
    # pids are opaque, and can't be inspected; this hack attempts to parse the inspect format to shorten it some
    # TODO: remove sigil for improved portability
    pid_regex = ~r/#PID<([\d\.]+)>/
    [_, addr] = Regex.run(pid_regex, inspect(pid))
    addr
  end

  defp format_timestamp({_date, {hr, mn, sc, ms}}), do: "#{hr}:#{mn}:#{sc}:#{ms}"

  defp format_message(msg), do: String.replace(to_string(msg), "\n", "\n    ")

  defp format_template(timestamp, level, pid, message) do
    "#{format_timestamp(timestamp)} [#{level}] #{format_pid(pid)}: #{format_message(message)}"
  end

  defp format!(level, message, timestamp, pid: pid, context: mod) do
    # turning a module to a string this way avoids the extra namespacing elixir does in the normal Module.to_string/1
    mod_str = Module.split(mod) |> Enum.join(".")
    base_str = format_template(timestamp, level, pid, message)
    "#{base_str} {#{mod_str}}\n"
  end

  defp format!(level, message, timestamp, pid: pid) do
    format_template(timestamp, level, pid, message) <> "\n"
  end

  def format(level, message, timestamp, metadata) do
    format!(level, message, timestamp, metadata)
  rescue
    e ->
      "!!! failed to format log message: #{Exception.format(:error, e)} (#{inspect(timestamp)} [#{
        level
      }] #{message} #{inspect(metadata)})\n"
  end

  # def format_log_message(level, message, timestamp, metadata) do
  #   {_date, {hr, mn, sc, ms}} = timestamp

  #   module =
  #     Keyword.get(metadata, :process_module, UNKNOWN)
  #     |> Module.split()
  #     |> Enum.join(".")

  #   pid_tag =
  #     if Keyword.has_key?(metadata, :pid) do

  #       [_, x, y, z] = Regex.run(~r/#PID<(\d+).(\d+).(\d+)>/, inspect(metadata[:pid]))
  #       "(#{x}.#{y}.#{z})"
  #     else
  #       ""
  #     end

  #   "#{hr}:#{mn}:#{sc}.#{ms} [#{level}] #{module}#{pid_tag}: #{message}\n"
  # rescue
  #   err -> "could not format log message: #{inspect({level, message, timestamp, metadata})} -- #{inspect(err)}\n"
  # end
end
