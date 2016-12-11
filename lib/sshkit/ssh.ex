defmodule SSHKit.SSH do
  @moduledoc """
  ```
  {:ok, conn} = SSHKit.SSH.connect('eg.io', user: 'me')
  {:ok, stdout, _, _} = SSHKit.SSH.run(conn, 'whoami')
  :ok = SSHKit.SSH.close(conn)

  IO.puts(stdout)
  ```
  """

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Channel

  @doc """
  ```
  {:ok, conn} = SSHKit.SSH.connect('eg.io', port: 2222, user: 'me', timeout: 1000)
  ```
  """
  def connect(host, options \\ []) do
    Connection.open(host, options)
  end

  @doc """
  ```
  :ok = SSHKit.SSH.close(conn)
  ```
  """
  def close(connection) do
    Connection.close(connection)
  end

  @doc """
  ```
  {:ok, data, status} = SSHKit.SSH.run(conn, 'whoami')
  ```
  """
  def run(connection, command, timeout \\ :infinity, handler \\ &capture/3) do
    case Channel.open(connection, timeout: timeout) do
      {:ok, channel} -> Channel.exec(channel, command, handler, {:ok, [], nil}, timeout)
      other -> other
    end
  end

  defp capture(channel, message, state = {:ok, buffer, status}) do
    id = channel.id

    case message do
      {:data, ^id, 0, data} -> {:ok, [{:normal, data} | buffer], status}
      {:data, ^id, 1, data} -> {:ok, [{:stderr, data} | buffer], status}
      {:exit_status, ^id, stat} -> {:ok, buffer, stat}
      _ -> state
    end
  end
end
