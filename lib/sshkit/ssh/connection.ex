defmodule SSHKit.SSH.Connection do
  @moduledoc """
  Defines a `SSHKit.SSH.Connection` struct representing a host connection.

  A connection struct has the following fields:

  * `host` - the name or IP of the remote host
  * `port` - the port to connect to
  * `options` - additional connection options
  * `ref` - the underlying `:ssh` connection ref
  """

  alias SSHKit.SSH.Connection
  alias SSHKit.Utils

  defstruct [:host, :port, :options, :ref, impl: :ssh]

  @default_impl_options [user_interaction: false]
  @default_connect_options [port: 22, timeout: :infinity, impl: :ssh]

  @doc """
  Opens a connection to an SSH server.

  The following options are allowed:

  * `:timeout`: A timeout in ms after which a command is aborted. Defaults to `:infinity`.
  * `:port`: The remote-port to connect to. Defaults to 22.
  * `:user`: The username with which to connect.
             Defaults to `$LOGNAME` or `$USER` on UNIX, or `$USERNAME` on Windows.
  * `:password`: The password to login with.
  * `:user_interaction`: Defaults to `false`.

  For a complete list of options and their default values, see:
  [`:ssh.connect/4`](http://erlang.org/doc/man/ssh.html#connect-4).

  Returns `{:ok, conn}` on success, `{:error, reason}` otherwise.
  """
  def open(host, options \\ [])
  def open(nil, _) do
    {:error, "No host given."}
  end
  def open(host, options) when is_binary(host) do
    open(to_charlist(host), options)
  end
  def open(host, options) do
    {details, opts} = extract(options)

    port    = details[:port]
    timeout = details[:timeout]
    impl    = details[:impl]

    case impl.connect(host, port, opts, timeout) do
      {:ok, ref} -> {:ok, build(host, port, opts, ref, impl)}
      err -> err
    end
  end

  defp extract(options) do
    connect_option_keys = Keyword.keys(@default_connect_options)
    {connect_options, impl_options} = Keyword.split(options, connect_option_keys)

    connect_options =
      @default_connect_options
      |> Keyword.merge(connect_options)

    impl_options =
      @default_impl_options
      |> Keyword.merge(impl_options)
      |> Utils.charlistify()

    {connect_options, impl_options}
  end

  defp build(host, port, options, ref, impl) do
    %Connection{host: host, port: port, options: options, ref: ref, impl: impl}
  end

  @doc """
  Closes an SSH connection.

  Returns `:ok`.

  For details, see [`:ssh.close/1`](http://erlang.org/doc/man/ssh.html#close-1).
  """
  def close(conn) do
    conn.impl.close(conn.ref)
  end

  @doc """
  Opens a new connection, based on the parameters of an existing one.

  The timeout value of the original connection is discarded.
  Other connection options are reused and may be overridden.

  Uses `SSHKit.SSH.open/2`.

  Returns `{:ok, conn}` or `{:error, reason}`.
  """
  def reopen(connection, options \\ []) do
    options =
      connection.options
      |> Keyword.put(:port, connection.port)
      |> Keyword.put(:impl, connection.impl)
      |> Keyword.merge(options)

    open(connection.host, options)
  end
end
