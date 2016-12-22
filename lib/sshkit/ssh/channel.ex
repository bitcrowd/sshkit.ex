defmodule SSHKit.SSH.Channel do
  defstruct [:connection, :type, :id]

  alias SSHKit.SSH.Channel

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
  Loops over channel messages until the channel is closed.

  Invokes `fun` for each channel message, passing the channel, message and
  `state` as arguments. `fun`'s return value is stored in `state`.

  `timeout` specifies the maximum delay between two subsequent messages.

  Returns `state` after the channel is closed.
  """
  def loop(channel, timeout \\ :infinity, state \\ nil, fun) do
    connection = channel.connection
    ref = connection.ref
    id = channel.id

    message = receive do
      {:ssh_cm, ^ref, msg} when elem(msg, 1) == id -> Tuple.delete_at(msg, 1)
    after
      timeout -> {:error, :timeout}
    end

    case message do
      {:data, _, data} -> :ssh_connection.adjust_window(ref, id, byte_size(data))
      _ -> :ok
    end

    state = fun.(channel, message, state)

    case message do
      {:closed} -> state
      _ -> loop(channel, timeout, state, fun)
    end
  end
end
