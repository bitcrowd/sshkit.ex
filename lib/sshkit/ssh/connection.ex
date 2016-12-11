defmodule SSHKit.SSH.Connection do
  defstruct [:host, :port, :options, :raw]

  alias SSHKit.SSH.Connection

  @doc """
  http://erlang.org/doc/man/ssh.html#connect-4
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
      {:ok, ref} -> {:ok, %Connection{host: host, port: port, options: options, raw: ref}}
      other -> other
    end
  end

  @doc """
  http://erlang.org/doc/man/ssh_connection.html#close-2
  """
  def close(connection) do
    :ssh.close(connection.raw)
  end

  @doc """
  """
  def reopen(connection, options \\ []) do
    options =
      connection.options
      |> Keyword.merge(options)
      |> Keyword.put(:port, connection.port)

    open(connection.host, options)
  end
end
