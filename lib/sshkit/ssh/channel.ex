defmodule SSHKit.SSH.Channel do
  alias SSHKit.SSH.Channel

  defstruct [:connection, :type, :id]

  @doc """
  Opens a channel on an SSH connection.

  On success, returns `{:ok, channel}`, where `channel` is a `Channel` struct.
  Returns `{:error, reason}` if a failure occurs.

  For more details, see [`:ssh_connection.session_channel/4`](http://erlang.org/doc/man/ssh_connection.html#session_channel-4).

  ## Options

  * `:type` - the type of the channel, defaults to `:session`
  * `:timeout` - defaults to `:infinity`
  * `:initial_window_size` - defaults to 128 KiB
  * `:max_packet_size` - defaults to 32 KiB
  """
  def open(connection, options \\ []) do
    type = Keyword.get(options, :type, :session)
    timeout = Keyword.get(options, :timeout, :infinity)
    ini_window_size = Keyword.get(options, :initial_window_size, 128 * 1024)
    max_packet_size = Keyword.get(options, :max_packet_size, 32 * 1024)

    case :ssh_connection.session_channel(connection.ref, ini_window_size, max_packet_size, timeout) do
      {:ok, id} -> {:ok, %Channel{connection: connection, type: type, id: id}}
      other -> other
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
  def exec(channel, command, timeout \\ :infinity) do
    :ssh_connection.exec(channel.connection.ref, channel.id, command, timeout)
  end

  @doc """
  Sends data across an open SSH channel.

  Returns `:ok`, `{:error, :timeout}` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send/5`](http://erlang.org/doc/man/ssh_connection.html#send-5).
  """
  def send(channel, type \\ 0, data, timeout \\ :infinity) do
    :ssh_connection.send(channel.connection.ref, channel.id, type, data, timeout)
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

  For more details, see [`:ssh_connection`](http://erlang.org/doc/man/ssh_connection.html).

  ## Messages

  The message tuples returned by `recv/3` correspond to the underlying Erlang
  channel messages with the channel id stripped. `recv` only listens to
  messages from the channel specified as the first argument.

  * `{:data, type, data}` - data has arrived, `type` is 0 "normal" or 1 "stderr"
  * `{:eof}` - indicates that no more data is to be sent by the remote process
  * `{:exit_signal, signal, msg, lang}` - remote execution terminated by `signal`
  * `{:exit_status, status}` - remote command terminated with exit code `status`
  * `{:closed}` - indicates that the channel has now been shut down
  """
  def recv(channel, timeout \\ :infinity) do
    ref = channel.connection.ref
    id = channel.id

    receive do
      {:ssh_cm, ^ref, msg} when elem(msg, 1) == id ->
        {:ok, Tuple.delete_at(msg, 1)}
    after
      timeout ->
        {:error, :timeout}
    end
  end

  @doc """
  Loops over channel messages until the channel is closed.

  Invokes `fun` for each channel message, passing the channel, message and
  `state` as arguments. `fun`'s return value is stored in `state`.

  `timeout` specifies the maximum delay between two subsequent messages.

  Returns `state` after the channel is closed, or `{:error, :timeout}`.
  """
  def loop(channel, timeout \\ :infinity, state \\ nil, fun) do
    case recv(channel, timeout) do
      {:ok, message} ->
        ref = channel.connection.ref
        id = channel.id

        case message do
          {:data, _, data} -> :ssh_connection.adjust_window(ref, id, byte_size(data))
          _ -> :ok
        end

        state = fun.(channel, message, state)

        case message do
          {:closed} -> state # we are done looping
          _ -> loop(channel, timeout, state, fun)
        end
      {:error, :timeout} -> {:error, :timeout}
    end
  end
end
