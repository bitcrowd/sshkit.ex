defmodule SSHKit.Channel do
  @moduledoc """
  Defines a `SSHKit.Channel` struct representing a connection channel.

  A channel struct has the following fields:

  * `connection` - the underlying `SSHKit.Connection`
  * `type` - the type of the channel, i.e. `:session`
  * `id` - the unique channel id
  """

  alias SSHKit.Connection

  defstruct [:connection, :type, :id]

  @type t() :: %__MODULE__{}

  # credo:disable-for-next-line
  @core Application.get_env(:sshkit, :ssh_connection, :ssh_connection)

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
  @spec open(Connection.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def open(conn, options \\ []) do
    timeout = Keyword.get(options, :timeout, :infinity)
    ini_window_size = Keyword.get(options, :initial_window_size, 128 * 1024)
    max_packet_size = Keyword.get(options, :max_packet_size, 32 * 1024)

    with {:ok, id} <- @core.session_channel(conn.ref, ini_window_size, max_packet_size, timeout) do
      {:ok, new(conn, id)}
    end
  end

  defp new(conn, id) do
    %__MODULE__{connection: conn, type: :session, id: id}
  end

  @doc """
  Closes an SSH channel.

  Returns `:ok`.

  For more details, see [`:ssh_connection.close/2`](http://erlang.org/doc/man/ssh_connection.html#close-2).
  """
  @spec close(t()) :: :ok
  def close(channel) do
    @core.close(channel.connection.ref, channel.id)
  end

  @doc """
  Executes a command on the remote host.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.exec/4`](http://erlang.org/doc/man/ssh_connection.html#exec-4).

  ## Processing channel messages

  `loop/4` may be used to process any channel messages received as a result of
  executing `command` on the remote.
  """
  @spec exec(t(), binary() | charlist(), timeout()) :: :success | :failure | {:error, term()}
  def exec(channel, command, timeout \\ :infinity)

  def exec(channel, command, timeout) when is_binary(command) do
    exec(channel, to_charlist(command), timeout)
  end

  def exec(channel, command, timeout) do
    @core.exec(channel.connection.ref, channel.id, command, timeout)
  end

  @doc """
  Activates a subsystem on a channel.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.subsystem/4`](http://erlang.org/doc/man/ssh_connection.html#subsystem-4).
  """
  @spec subsystem(t(), binary(), keyword()) :: :success | :failure | {:error, term()}
  def subsystem(channel, subsystem, options \\ []) do
    timeout = Keyword.get(options, :timeout, :infinity)
    @core.subsystem(channel.connection.ref, channel.id, to_charlist(subsystem), timeout)
  end

  @doc """
  Allocates PTTY.

  Returns `:success`, `:failure` or `{:error, reason}`.

  For more details, see [`:ssh_connection.ptty_alloc/4`](http://erlang.org/doc/man/ssh_connection.html#ptty_alloc-4).
  """
  @spec ptty(t(), keyword(), timeout()) :: :success | :failure | {:error, term()}
  def ptty(channel, options \\ [], timeout \\ :infinity) do
    @core.ptty_alloc(channel.connection.ref, channel.id, options, timeout)
  end

  @doc """
  Sends data across an open SSH channel.

  `data` may be an enumerable, e.g. a `File.Stream` or `IO.Stream`.

  Returns `:ok`, `{:error, :timeout}` or `{:error, :closed}`.

  For more details, see [`:ssh_connection.send/5`](http://erlang.org/doc/man/ssh_connection.html#send-5).
  """
  @spec send(t(), non_neg_integer(), term(), timeout()) ::
          :ok | {:error, :timeout} | {:error, :closed}
  def send(channel, type \\ 0, data, timeout \\ :infinity)

  def send(channel, type, data, timeout) when is_binary(data) or is_list(data) do
    @core.send(channel.connection.ref, channel.id, type, data, timeout)
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
  @spec eof(t()) :: :ok | {:error, term()}
  def eof(channel) do
    @core.send_eof(channel.connection.ref, channel.id)
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
  @spec recv(t(), timeout()) :: {:ok, tuple()} | {:error, term()}
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
  Adjusts the flow control window.

  Returns `:ok`.

  For more details, see [`:ssh_connection.adjust_window/3`](http://erlang.org/doc/man/ssh_connection.html#adjust_window-3).
  """
  @spec adjust(t(), non_neg_integer()) :: :ok
  def adjust(channel, size) when is_integer(size) do
    @core.adjust_window(channel.connection.ref, channel.id, size)
  end

  @doc """
  Flushes any pending messages for the given channel.

  Returns `:ok`.
  """
  @spec flush(t(), timeout()) :: :ok
  def flush(channel, timeout \\ 0) do
    ref = channel.connection.ref
    id = channel.id

    receive do
      {:ssh_cm, ^ref, msg} when elem(msg, 1) == id -> flush(channel)
    after
      timeout -> :ok
    end
  end
end
