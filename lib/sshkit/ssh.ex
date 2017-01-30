defmodule SSHKit.SSH do
  @moduledoc ~S"""
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

  ## Example

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

  ## Example

  ```
  :ok = SSHKit.SSH.close(conn)
  ```
  """
  def close(connection) do
    Connection.close(connection)
  end

  @doc """
  Executes a command on the remote.

  Returns `{:ok, chan}` or `{:error, reason}`.

  The returned channel will be closed once the command has exited.

  ## Example

  ```
  {:ok, chan} = SSHKit.SSH.start(conn, 'scp -f /home/code/sshkit/README.md')
  :ok = SSHKit.SSH.Channel.send(chan, <<0>>)
  SSHKit.SSH.Channel.loop(chan, :infinity, :open, …)
  ```
  """
  def start(connection, command, timeout \\ :infinity) do
    case Channel.open(connection, timeout: timeout) do
      {:ok, channel} ->
        case Channel.exec(channel, command, timeout) do
          :success -> {:ok, channel}
          :failure -> {:error, :failure}
          other -> other
        end
      other -> other
    end
  end

  @doc """
  Executes a command on the remote and listens to incoming messages.

  Using the default handler, returns `{:ok, output, status}` or
  `{:error, reason}`.

  By default, command output is captured into a list of tuples of the form
  `{:normal, data}` or `{:stderr, data}`.

  A custom handler function can be provided to handle channel messages.
  For further details on handling incoming messages,
  see `SSHKit.SSH.Channel.loop/4`.

  If the remote process expects you to send a first message before sending any
  data itself, use:

  1. `SSHKit.SSH.start/3` to start the command,
  2. `SSHKit.SSH.Channel.send/4` to send your initial message, and then
  3. `SSHKit.SSH.Channel.loop/4` for the remaining communication.

  ## Example

  ```
  {:ok, output, status} = SSHKit.SSH.run(conn, 'uptime')
  IO.inspect(output)
  ```
  """
  def run(connection, command, timeout \\ :infinity, ini \\ {[], nil}, handler \\ &capture/3) do
    case start(connection, command, timeout) do
      {:ok, channel} -> Channel.loop(channel, timeout, ini, handler) |> elem(1)
      other -> other
    end
  end

  defp capture(_, message, state = {buffer, status}) do
    next = case message do
      {:data, 0, data} -> {[{:normal, data} | buffer], status}
      {:data, 1, data} -> {[{:stderr, data} | buffer], status}
      {:exit_status, code} -> {buffer, code}
      {:closed} -> {:ok, Enum.reverse(buffer), status}
      _ -> state
    end

    {:cont, next}
  end
end
