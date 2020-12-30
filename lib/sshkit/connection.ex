defmodule SSHKit.Connection do
  @moduledoc """
  Defines a `SSHKit.Connection` struct representing a host connection.

  A connection struct has the following fields:

  * `host` - the name or IP of the remote host
  * `port` - the port connected to
  * `options` - additional connection options
  * `ref` - the underlying `:ssh` connection ref
  """

  alias SSHKit.Utils

  # TODO: Add :tag allowing arbitrary data to be attached?
  defstruct [:host, :port, :options, :ref]

  @type t() :: %__MODULE__{}

  # credo:disable-for-next-line
  @core Application.get_env(:sshkit, :ssh, :ssh)

  @default_ssh_options [user_interaction: false]
  @default_connect_options [port: 22, timeout: :infinity]

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
  @spec open(binary() | charlist(), keyword()) :: {:ok, t()} | {:error, term()}
  def open(host, options \\ [])

  def open(host, options) when is_binary(host) do
    open(to_charlist(host), options)
  end

  def open(host, options) when is_list(host) do
    {details, opts} = extract(options)

    port = details[:port]
    timeout = details[:timeout]

    case @core.connect(host, port, opts, timeout) do
      {:ok, ref} -> {:ok, new(host, port, opts, ref)}
      err -> err
    end
  end

  defp extract(options) do
    connect_option_keys = Keyword.keys(@default_connect_options)
    {connect_options, ssh_options} = Keyword.split(options, connect_option_keys)

    connect_options =
      @default_connect_options
      |> Keyword.merge(connect_options)

    ssh_options =
      @default_ssh_options
      |> Keyword.merge(ssh_options)
      |> Utils.charlistify()

    {connect_options, ssh_options}
  end

  defp new(host, port, options, ref) do
    %__MODULE__{host: host, port: port, options: options, ref: ref}
  end

  @doc """
  Closes an SSH connection.

  Returns `:ok`.

  For details, see [`:ssh.close/1`](http://erlang.org/doc/man/ssh.html#close-1).
  """
  @spec close(t()) :: :ok
  def close(conn) do
    @core.close(conn.ref)
  end

  @doc """
  Opens a new connection, based on the parameters of an existing one.

  The timeout value of the original connection is discarded.
  Other connection options are reused and may be overridden.

  Uses `SSHKit.Connection.open/2`.

  Returns `{:ok, conn}` or `{:error, reason}`.
  """
  @spec reopen(t(), keyword()) :: {:ok, t()} | {:error, term()}
  def reopen(conn, options \\ []) do
    options =
      conn.options
      |> Keyword.put(:port, conn.port)
      |> Keyword.merge(options)

    open(conn.host, options)
  end

  @doc """
  Returns information about a connection.

  For OTP versions prior to 21.1, only `:client_version`, `:server_version`,
  `:user`, `:peer` and `:sockname` are available.

  For details, see [`:ssh.connection_info/1`](http://erlang.org/doc/man/ssh.html#connection_info-1).
  """
  @spec info(t()) :: keyword()
  def info(conn) do
    if function_exported?(@core, :connection_info, 1) do
      @core.connection_info(conn.ref)
    else
      @core.connection_info(conn.ref, [:client_version, :server_version, :user, :peer, :sockname])
    end
  end
end
