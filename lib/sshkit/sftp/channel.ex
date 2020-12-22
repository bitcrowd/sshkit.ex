defmodule SSHKit.SFTP.Channel do
  @moduledoc false

  alias SSHKit.Connection

  defstruct [:connection, :id, impl: :ssh_sftp]

  @type t() :: %__MODULE__{}
  @type handle() :: term()

  @spec start(Connection.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def start(conn, options \\ []) do
    {impl, options} = Keyword.pop(options, :impl, :ssh_sftp)

    with {:ok, id} <- impl.start_channel(conn.ref, options) do
      {:ok, new(conn, id, impl)}
    end
  end

  defp new(conn, id, impl) do
    %__MODULE__{connection: conn, id: id, impl: impl}
  end

  @spec stop(t()) :: :ok
  def stop(chan) do
    chan.impl.stop_channel(chan.id)
  end

  @spec mkdir(t(), binary(), timeout()) :: :ok | {:error, term()}
  def mkdir(chan, name, timeout \\ :infinity) do
    chan.impl.make_dir(chan.id, name, timeout)
  end

  @spec open(t(), binary(), [:read | :write | :append | :binary | :raw], timeout()) ::
          {:ok, handle()} | {:error, term()}
  def open(chan, name, mode, timeout \\ :infinity) do
    chan.impl.open(chan.id, name, mode, timeout)
  end

  @spec close(t(), handle(), timeout()) :: :ok | {:error, term()}
  def close(chan, handle, timeout \\ :infinity) do
    chan.impl.close(chan.id, handle, timeout)
  end

  @spec write(t(), handle(), iodata(), timeout()) :: :ok | {:error, term()}
  def write(chan, handle, data, timeout \\ :infinity) do
    chan.impl.write(chan.id, handle, data, timeout)
  end
end
