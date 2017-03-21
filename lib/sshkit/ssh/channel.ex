defmodule SSHKit.SSH.Channel do
  alias SSHKit.SSH.Channel

  defstruct [:connection, :type, :id]

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

    case :ssh_connection.session_channel(connection.ref, ini_window_size, max_packet_size, timeout) do
      {:ok, id} -> {:ok, %Channel{connection: connection, type: :session, id: id}}
      err -> err
    end
  end

  @doc """
  Closes an SSH channel.

  Returns `:ok`.

  For more details, see [`:ssh_connection.close/2`](http://erlang.org/doc/man/ssh_connection.html#close-2).
  """
  def close(channel) do
    :ssh_connection.close(channel.connection.ref, channel.id)
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
    :ssh_connection.exec(channel.connection.ref, channel.id, command, timeout)
  end

  @doc """
  Sends data across an open SSH channel.

  `data` may be an enumerable, e.g. a `File.Stream` or `IO.Stream`.

  Returns `:ok`, `{:error, :timeout}` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send/5`](http://erlang.org/doc/man/ssh_connection.html#send-5).
  """
  def send(channel, type \\ 0, data, timeout \\ :infinity)

  def send(channel, type, data, timeout) when is_binary(data) or is_list(data) do
    :ssh_connection.send(channel.connection.ref, channel.id, type, data, timeout)
  end

  def send(channel, type, data, timeout) do
    Enum.each(data, fn datum -> :ok = send(channel, type, datum, timeout) end)
  end

  @doc """
  Sends an EOF message on an open SSH channel.

  Returns `:ok` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send_eof/2`](http://erlang.org/doc/man/ssh_connection.html#send_eof-2).
  """
  def eof(channel) do
    :ssh_connection.send_eof(channel.connection.ref, channel.id)
  end

  @doc """
  Receive the next message on an open SSH channel.

  Returns `{:ok, message}` or `{:error, :timeout}`.

  Only listens to messages from the channel specified as the first argument.

  ## Messages

  The message tuples returned by `recv/3` correspond to the underlying Erlang
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
    :ssh_connection.adjust_window(channel.connection.ref, channel.id, size)
  end

  @doc """
  Loops over channel messages until the channel is closed, or looping is stopped
  explicitly.

  Expects an accumulator on each call that determines how to proceed:

  1. `{:cont, state}`

    The loop will wait for an inbound message. It will then pass the message and
    current `state` to the looping function. `fun`'s return value is the
    accumulator for the next cycle.

  2. `{:cont, message, state}`

    Sends a message to the remote end of the channel before waiting for a
    message as outlined in the `{:cont, state}` case above. `message` may be one
    of the following:

      * `{0, data}` or `{1, data}` - sends normal or stderr data to the remote
      * `data` - is a shortcut for `{0, data}`
      * `:eof` - sends EOF

  3. `{:halt, state}`

    Terminates the loop, returning `{:halted, state}`.

  4. `{:suspend, state}`

    Suspends the loop, returning `{:suspended, state, continuation}`.
    `continuation` is a function that accepts a new accumulator value and that,
    when called, will resume the loop.

  `timeout` specifies the maximum wait time for receiving and sending individual
  messages.

  Once the final `{:closed, channel}` message is received, the loop will
  terminate and return `{:done, state}`. The channel will be closed if it has
  not been closed before.
  """
  def loop(channel, timeout \\ :infinity, acc, fun)

  def loop(channel, timeout, {:cont, msg, acc}, fun) do
    case lsend(channel, msg, timeout) do
      :ok -> loop(channel, timeout, {:cont, acc}, fun)
      err -> halt(channel, err)
    end
  end

  def loop(channel, timeout, {:cont, acc}, fun) do
    case recv(channel, timeout) do
      {:ok, msg} ->
        if elem(msg, 0) == :closed do
          {_, acc} = fun.(msg, acc)
          done(channel, acc)
        else
          :ok = ljust(channel, msg)
          loop(channel, timeout, fun.(msg, acc), fun)
        end
      err -> halt(channel, err)
    end
  end

  def loop(channel, _, {:halt, acc}, _) do
    halt(channel, acc)
  end

  def loop(channel, timeout, {:suspend, acc}, fun) do
    suspend(channel, acc, fun, timeout)
  end

  defp halt(channel, acc) do
    :ok = close(channel)
    :ok = flush(channel)
    {:halted, acc}
  end

  defp suspend(channel, acc, fun, timeout) do
    {:suspended, acc, &loop(channel, timeout, &1, fun)}
  end

  defp done(_, acc) do
    {:done, acc}
  end

  defp lsend(_, nil, _), do: :ok

  defp lsend(channel, :eof, _), do: eof(channel)

  defp lsend(channel, {type, data}, timeout) do
    send(channel, type, data, timeout)
  end

  defp lsend(channel, data, timeout) do
    send(channel, 0, data, timeout)
  end

  defp ljust(channel, {:data, _, _, data}) do
    adjust(channel, byte_size(data))
  end

  defp ljust(_, _), do: :ok
end
