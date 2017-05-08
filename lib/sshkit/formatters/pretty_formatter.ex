defmodule SSHKit.Formatters.PrettyFormatter do
  @moduledoc """
  Formatter that uses `IO.ANSI` to colorize connection details.
  """

  use SSHKit.Formatter

  def puts_connect(host = %Host{}) do
    host.uuid
    |> wrap_uuid()
    |> List.flatten(["Connecting to ", IO.ANSI.bright, host.name, IO.ANSI.reset, "\n"])
    |> IO.write()
  end

  def puts_exec(uuid, command) do
    uuid
    |> wrap_uuid()
    |> List.flatten(["Running ", IO.ANSI.yellow, command, IO.ANSI.reset, "\n"])
    |> IO.write()
  end

  def puts_receive(uuid, type, message) do
    String.trim_trailing(message) <> "\n"
    |> String.split("\n")
    |> Enum.drop(-1)
    |> Enum.map(&(wrap_uuid(uuid) ++ [color_std(type), &1, IO.ANSI.reset, "\n"]))
    |> IO.write()
  end

  defp color_std(type) do
    case type do
      :stderr -> IO.ANSI.red
            _ -> IO.ANSI.green
    end
  end

  defp wrap_uuid(uuid) do
    case uuid do
      nil -> []
      _ -> ["[", IO.ANSI.green, uuid, IO.ANSI.reset, "] "]
    end
  end
end
