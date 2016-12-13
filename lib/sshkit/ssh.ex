defmodule SSHKit.SSH do
  @moduledoc ~S"""
  SSH utilities.

  Provides convenience functions for working with SSH connections
  and executing commands on remote hosts.

  ## Examples

  ```
  {:ok, conn} = SSHKit.SSH.connect('eg.io', user: 'me')
  {:ok, output, status} = SSHKit.SSH.run(conn, 'uptime')
  :ok = SSHKit.SSH.close(conn)

  log = fn {type, data} ->
    case type do
      :normal -> IO.write(data)
      :stderr -> IO.write([IO.ANSI.red, data, IO.ANSI.reset])
    end
  end

  Enum.each(output, log)
  IO.puts("$?: #{status}")
  ```
  """

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Channel

  @doc """
  Establishes a connection to an SSH server.

  Uses `SSHKit.SSH.Connection.open/2` to open a connection.

  ```
  {:ok, conn} = SSHKit.SSH.connect('eg.io', port: 2222, user: 'me', timeout: 1000)
  ```
  """
  def connect(host, options \\ []) do
    Connection.open(host, options)
  end

  @doc """
  Closes an SSH connection.

  Uses `SSHKit.SSH.Connection.close/1` to close the connection.

  ```
  :ok = SSHKit.SSH.close(conn)
  ```
  """
  def close(connection) do
    Connection.close(connection)
  end

  @doc """
  Executes a command on the remote.

  Using the default handler, returns `{:ok, output, status}` or
  `{:error, reason}`.

  By default, command output is captured into a list of tuples of the form
  `{:normal, data}` or `{:stderr, data}`.

  A custom handler function can be provided to handle channel messages.

  ```
  {:ok, output, status} = SSHKit.SSH.run(conn, 'uptime')
  ```
  """
  def run(connection, command, timeout \\ :infinity, ini \\ {:ok, [], nil}, handler \\ &capture/3) do
    case Channel.open(connection, timeout: timeout) do
      {:ok, channel} -> Channel.exec(channel, command, timeout, ini, handler)
      other -> other
    end
  end

  defp capture(_channel, message, state = {:ok, buffer, status}) do
    case message do
      {:data, 0, data} -> {:ok, [{:normal, data} | buffer], status}
      {:data, 1, data} -> {:ok, [{:stderr, data} | buffer], status}
      {:exit_status, stat} -> {:ok, Enum.reverse(buffer), stat}
      _ -> state
    end
  end
end
