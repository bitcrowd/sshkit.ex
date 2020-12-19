defmodule SSHKit.Channel do
  @moduledoc """
  Defines a `SSHKit.Channel` struct representing a connection channel.

  A channel struct has the following fields:

  * `connection` - the underlying `SSHKit.Connection`
  * `type` - the type of the channel, i.e. `:session`
  * `id` - the unique channel id
  """

  defstruct [:connection, :type, :id, impl: :ssh_connection]

  @doc """
  Opens a channel on an SSH connection.

  On success, returns `{:ok, channel}`, where `channel` is a `Channel` struct.
  Returns `{:error, reason}` if a failure occurs.

  For more details, see [`:ssh_connection.session_channel/4`](http://erlang.org/doc/man/ssh_connection.html#session_channel-4).

  ## Options

  * `:timeout` - defaults to `:infinity`
  * `:initial_window_size` - defaults to 128 KiB
  * `:max_packet_size` - defaults to 32 KiB
  """
  def open(connection, options \\ []) do
    timeout = Keyword.get(options, :timeout, :infinity)
    ini_window_size = Keyword.get(options, :initial_window_size, 128 * 1024)
    max_packet_size = Keyword.get(options, :max_packet_size, 32 * 1024)
    impl = Keyword.get(options, :impl, :ssh_connection)

    case impl.session_channel(connection.ref, ini_window_size, max_packet_size, timeout) do
      {:ok, id} -> {:ok, new(connection, id, impl)}
      err -> err
    end
  end

  defp new(connection, id, impl) do
    %__MODULE__{connection: connection, type: :session, id: id, impl: impl}
  end

  @doc """
  Activates a subsystem on a channel.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.subsystem/4`](http://erlang.org/doc/man/ssh_connection.html#subsystem-4).
  """
  @spec subsystem(channel :: struct(), subsystem :: String.t(), options :: list()) ::
          :success | :failure | {:error, reason :: String.t()}
  def subsystem(channel, subsystem, options \\ []) do
    timeout = Keyword.get(options, :timeout, :infinity)
    impl = Keyword.get(options, :impl, :ssh_connection)

    impl.subsystem(channel.connection.ref, channel.id, to_charlist(subsystem), timeout)
  end

  @doc """
  Closes an SSH channel.

  Returns `:ok`.

  For more details, see [`:ssh_connection.close/2`](http://erlang.org/doc/man/ssh_connection.html#close-2).
  """
  def close(channel) do
    channel.impl.close(channel.connection.ref, channel.id)
  end

  @doc """
  Executes a command on the remote host.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.exec/4`](http://erlang.org/doc/man/ssh_connection.html#exec-4).

  ## Processing channel messages

  `loop/4` may be used to process any channel messages received as a result of
  executing `command` on the remote.
  """
  def exec(channel, command, timeout \\ :infinity)

  def exec(channel, command, timeout) when is_binary(command) do
    exec(channel, to_charlist(command), timeout)
  end

  def exec(channel, command, timeout) do
    channel.impl.exec(channel.connection.ref, channel.id, command, timeout)
  end

  @doc """
  Allocates PTTY.

  Returns `:success`.

  For more details, see [`:ssh_connection.ptty_alloc/4`](http://erlang.org/doc/man/ssh_connection.html#ptty_alloc-4).
  """
  def ptty(channel, options \\ [], timeout \\ :infinity) do
    channel.impl.ptty_alloc(channel.connection.ref, channel.id, options, timeout)
  end

  @doc """
  Sends data across an open SSH channel.

  `data` may be an enumerable, e.g. a `File.Stream` or `IO.Stream`.

  Returns `:ok`, `{:error, :timeout}` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send/5`](http://erlang.org/doc/man/ssh_connection.html#send-5).
  """
  def send(channel, type \\ 0, data, timeout \\ :infinity)

  def send(channel, type, data, timeout) when is_binary(data) or is_list(data) do
    channel.impl.send(channel.connection.ref, channel.id, type, data, timeout)
  end

  def send(channel, type, data, timeout) do
    Enum.reduce_while(data, :ok, fn
      datum, :ok -> {:cont, send(channel, type, datum, timeout)}
      _, err -> {:halt, err}
    end)
  end

  @doc """
  Sends an EOF message on an open SSH channel.

  Returns `:ok` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send_eof/2`](http://erlang.org/doc/man/ssh_connection.html#send_eof-2).
  """
  def eof(channel) do
    channel.impl.send_eof(channel.connection.ref, channel.id)
  end

  @doc """
  Receive the next message on an open SSH channel.

  Returns `{:ok, message}` or `{:error, :timeout}`.

  Only listens to messages from the channel specified as the first argument.

  ## Messages

  The message tuples returned by `recv/2` correspond to the underlying Erlang
  channel messages with the channel id replaced by the SSHKit channel struct:

  * `{:data, channel, type, data}`
  * `{:eof, channel}`
  * `{:exit_signal, channel, signal, msg, lang}`
  * `{:exit_status, channel, status}`
  * `{:closed, channel}`

  For more details, see [`:ssh_connection`](http://erlang.org/doc/man/ssh_connection.html).
  """
  def recv(channel, timeout \\ :infinity) do
    ref = channel.connection.ref
    id = channel.id

    receive do
      {:ssh_cm, ^ref, msg} when elem(msg, 1) == id ->
        msg = msg |> Tuple.delete_at(1) |> Tuple.insert_at(1, channel)
        {:ok, msg}
    after
      timeout -> {:error, :timeout}
    end
  end

  @doc """
  Flushes any pending messages for the given channel.

  Returns `:ok`.
  """
  def flush(channel, timeout \\ 0) do
    ref = channel.connection.ref
    id = channel.id

    receive do
      {:ssh_cm, ^ref, msg} when elem(msg, 1) == id -> flush(channel)
    after
      timeout -> :ok
    end
  end

  @doc """
  Adjusts the flow control window.

  Returns `:ok`.

  For more details, see [`:ssh_connection.adjust_window/3`](http://erlang.org/doc/man/ssh_connection.html#adjust_window-3).
  """
  def adjust(channel, size) when is_integer(size) do
    channel.impl.adjust_window(channel.connection.ref, channel.id, size)
  end
end
