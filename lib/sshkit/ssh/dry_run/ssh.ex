defmodule SSHKit.SSH.DryRun.SSH do
  @moduledoc false

  require Logger

  def connect(host, port, _options, _timeout) do
    Logger.info("Connect: #{host}:#{port}")

    {:ok, "#{host}:#{port}"}
  end

  def close(ref) do
    Logger.info("Disconnected #{ref}")

    :ok
  end
end
