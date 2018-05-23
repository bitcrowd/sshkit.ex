defmodule SSHKit.SSH do
  @moduledoc ~S"""
  Provides convenience functions for working with SSH connections
  and executing commands on remote hosts.

  ## Examples

  ```
  {:ok, conn} = SSHKit.SSH.connect("eg.io", user: "me")
  {:ok, output, status} = SSHKit.SSH.run(conn, "uptime")
  :ok = SSHKit.SSH.close(conn)

  Enum.each(output, fn
    {:stdout, data} -> IO.write(data)
    {:stderr, data} -> IO.write([IO.ANSI.red, data, IO.ANSI.reset])
  end)

  IO.puts("$?: #{status}")
  ```
  """

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Channel

  @doc """
  Establishes a connection to an SSH server.

  Uses `SSHKit.SSH.Connection.open/2` to open a connection.

  `options_or_function` can either be a list of options or a function.
  If it is a list, it is considered to be a list of options as described in
  `SSHKit.SSH.Connection.open/2`. If it is a function, then it is equivalent to
  calling `connect(host, [], options_or_function)`.

  See the documentation for `connect/3` for more information on this function.

  ## Example

  ```
  {:ok, conn} = SSHKit.SSH.connect("eg.io", port: 2222, user: "me", timeout: 1000)
  ```
  """
  @callback connect(binary(), keyword() | fun()) :: {:ok, Connection.t} | {:error, any()}
  def connect(host, options_or_function \\ [])
  def connect(host, function) when is_function(function), do: connect(host, [], function)
  def connect(host, options) when is_list(options), do: Connection.open(host, options)

  @doc """
  Similar to `connect/2` but expects a function as its last argument.

  The connection is opened, given to the function as an argument and
  automatically closed after the function returns, regardless of any
  errors raised while executing the function.

  Returns `{:ok, function_result}` in case of success,
  `{:error, reason}` otherwise.

  ## Examples

  ```
  SSH.connect("eg.io", port: 2222, user: "me", fn conn ->
    SCP.upload(conn, "list.txt")
  end)
  ```

  See `SSHKit.SSH.Connection.open/2` for the list of available `options`.
  """
  def connect(host, options, function) do
    case connect(host, options) do
      {:ok, conn} ->
        try do
          {:ok, function.(conn)}
        after
          :ok = close(conn)
        end
      other -> other
    end
  end

  @doc """
  Closes an SSH connection.

  Uses `SSHKit.SSH.Connection.close/1` to close the connection.

  ## Example

  ```
  :ok = SSHKit.SSH.close(conn)
  ```
  """
  @callback close(Connection.t) :: :ok
  def close(connection) do
    Connection.close(connection)
  end

  @doc """
  Executes a command on the remote and aggregates incoming messages.

  Using the default handler, returns `{:ok, output, status}` or `{:error,
  reason}`. By default, command output is captured into a list of tuples of the
  form `{:stdout, data}` or `{:stderr, data}`.

  A custom handler function can be provided to handle channel messages.

  For further details on handling incoming messages,
  see `SSHKit.SSH.Channel.loop/4`.

  ## Options

  * `:timeout` - maximum wait time between messages, defaults to `:infinity`
  * `:fun` - handler function passed to `SSHKit.SSH.Channel.loop/4`
  * `:acc` - initial accumulator value used in the loop

  Any other options will be passed on to `SSHKit.SSH.Channel.open/2` when
  creating the channel for executing the command.

  ## Example

  ```
  {:ok, output, status} = SSHKit.SSH.run(conn, "uptime")
  IO.inspect(output)
  ```
  """
  @callback run(Connection.t, binary(), keyword()) :: any()
  def run(connection, command, options \\ []) do
    {acc, options} = Keyword.pop(options, :acc, {:cont, {[], nil}})
    {fun, options} = Keyword.pop(options, :fun, &capture/2)

    timeout = Keyword.get(options, :timeout, :infinity)

    with {:ok, channel} <- Channel.open(connection, options) do
      case Channel.exec(channel, command, timeout) do
        :success ->
          channel
          |> Channel.loop(timeout, acc, fun)
          |> elem(1)
        :failure ->
          {:error, :failure}
        err ->
          err
      end
    end
  end

  defp capture(message, acc = {buffer, status}) do
    next = case message do
      {:data, _, 0, data} ->
        {[{:stdout, data} | buffer], status}
      {:data, _, 1, data} ->
        {[{:stderr, data} | buffer], status}
      {:exit_status, _, code} ->
        {buffer, code}
      {:closed, _} ->
        {:ok, Enum.reverse(buffer), status}
      _ ->
        acc
    end

    {:cont, next}
  end
end
