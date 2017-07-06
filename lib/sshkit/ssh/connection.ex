defmodule SSHKit.SSH.Connection do
  @moduledoc """
  Defines a `SSHKit.SSH.Connection` struct representing a host connection.

  A connection struct has the following fields:

  * `host` - the name or IP of the remote host
  * `port` - the port to connect to
  * `options` - additional connection options
  * `ref` - the underlying `:ssh` connection ref
  """

  alias SSHKit.SSH.{Connection, DryRun}
  alias SSHKit.Utils

  defstruct [:host, :port, :options, :ref, :ssh_modules]

  @ssh_modules %{ssh: :ssh, ssh_connection: :ssh_connection}
  @dry_run_ssh_modules %{ssh: DryRun.SSH, ssh_connection: DryRun.SSHConnection}

  @doc """
  Opens a connection to an SSH server.

  The following options are allowed:

  * `:timeout`: A timeout in ms after which a command is aborted. Defaults to `:infinity`.
  * `:port`: The remote-port to connect to. Defaults to 22.
  * `:user`: The username with which to connect.
             Defaults to `$LOGNAME`, or `$USER` on UNIX, or `$USERNAME` on windows.
  * `:password`: The password to login with
  * `:dry_run`: If set to `true` no actual connection to the remote is established.
                Instead all commands a logged. Defaults to `false`.
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
    { ssh_options, sshkit_options } = fetch_options(options)

    ssh = ssh_module(sshkit_options)
    case ssh.connect(host, sshkit_options.port, ssh_options, sshkit_options.timeout) do
      {:ok, ref} -> {
        :ok,
        %Connection{
          host: host,
          port: sshkit_options.port,
          options: ssh_options,
          ref: ref,
          ssh_modules: sshkit_options.ssh_modules
        }
      }
      err -> err
    end
  end

  @default_erlang_ssh_options [user_interaction: false]
  defp fetch_options(options) do
    dry_run = Keyword.get(options, :dry_run, false)
    ssh_modules = if dry_run do
      @dry_run_ssh_modules
    else
      @ssh_modules
    end

    sshkit_options = %{
      port: Keyword.get(options, :port, 22),
      timeout: Keyword.get(options, :timeout, :infinity),
      ssh_modules: Keyword.get(options, :ssh_modules, ssh_modules),
      dry_run: dry_run
    }

    erlang_ssh_options =
      @default_erlang_ssh_options
      |> Keyword.merge(options)
      |> Keyword.drop([:port, :timeout, :ssh_modules, :dry_run])
      |> Utils.charlistify()

    { erlang_ssh_options, sshkit_options }
  end

  defp ssh_module(conn) do
    Map.fetch!(conn.ssh_modules, :ssh)
  end

  @doc """
  Closes an SSH connection.

  Returns `:ok`.

  For details, see [`:ssh.close/1`](http://erlang.org/doc/man/ssh.html#close-1).
  """
  def close(conn) do
    ssh_module(conn).close(conn.ref)
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
      |> Keyword.merge(options)

    open(connection.host, options)
  end
end
