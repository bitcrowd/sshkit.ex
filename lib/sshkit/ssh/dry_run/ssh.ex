defmodule SSHKit.SSH.DryRun.SSH do
  @moduledoc false

  require Logger

  def connect(host, port, options, _timeout) do
    login_identifier = if options[:user] do
      "#{options[:user]}@#{host}:#{port}"
    else
      "#{host}:#{port}"
    end

    Logger.info("Connect: #{login_identifier}")
    {:ok, login_identifier}
  end

  def close(ref) do
    Logger.info("Disconnect: #{ref}")

    :ok
  end
end
