defmodule SSHKit.SCP.Command do
  @moduledoc false

  import SSHKit.Utils

  @flags [verbose: "-v", preserve: "-p", recursive: "-r"]

  def build(:upload, path, options) do
    scp("-t", path, options)
  end

  def build(:download, path, options) do
    scp("-f", path, options)
  end

  defp scp(mode, path, options) do
    "scp #{mode}" |> flag(options) |> at(path)
  end

  defp flag(command, options) do
    @flags
    |> Enum.filter(fn {key, _} -> Keyword.get(options, key, false) end)
    |> Enum.into([command], fn {_, flag} -> flag end)
    |> Enum.join(" ")
  end

  defp at(command, path) do
    "#{command} #{shellescape(path)}"
  end
end
