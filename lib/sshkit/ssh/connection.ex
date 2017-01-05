defmodule SSHKit.SSH.Connection do
  alias SSHKit.SSH.Connection

  defstruct [:host, :port, :options, :ref]

  @doc """
  Opens a connection to an SSH server.

  A timeout in ms can be provided through the `:timeout` option.
  The default value is `:infinity`.

  A few more, common options are `:port`, `:user` and `:password`.
  Port defaults to `22`, user to `$LOGNAME` or `$USER` on UNIX,
  `$USERNAME` on Windows.

  The `:user_interaction` option is set to false by default.

  For a complete list of options and their default values, see:
  [`:ssh.connect/4`](http://erlang.org/doc/man/ssh.html#connect-4).

  Returns `{:ok, conn}` on success, `{:error, reason}` otherwise.
  """
  def open(host, options \\ []) do
    port = Keyword.get(options, :port, 22)
    timeout = Keyword.get(options, :timeout, :infinity)

    defaults = [user_interaction: false]

    options =
      defaults
      |> Keyword.merge(options)
      |> Keyword.drop([:port, :timeout])

    case :ssh.connect(host, port, options, timeout) do
      {:ok, ref} -> {:ok, %Connection{host: host, port: port, options: options, ref: ref}}
      other -> other
    end
  end

  @doc """
  Closes an SSH connection.

  Returns `:ok`.

  For details, see [`:ssh.close/1`](http://erlang.org/doc/man/ssh.html#close-1).
  """
  def close(connection) do
    :ssh.close(connection.ref)
  end

  @doc """
  Opens a new connection, based on the parameters of an existing one.

  The timeout value of the original connection is discarded.
  Other connection options are reused and may be overriden.

  Uses `SSHKit.SSH.open/2`.

  Returns `{:ok, conn}` or `{:error, reason}`.
  """
  def reopen(connection, options \\ []) do
    options =
      connection.options
      |> Keyword.put(:port, connection.port)
      |> Keyword.merge(options)

    open(connection.host, options)
  end
end
