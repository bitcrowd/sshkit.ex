defmodule SSHKit.SFTP.Channel do
  @moduledoc false

  alias SSHKit.Connection

  defstruct [:connection, :id]

  @type t() :: %__MODULE__{}
  @type handle() :: term()

  # credo:disable-for-next-line
  @core Application.get_env(:sshkit, :ssh_sftp, :ssh_sftp)

  @spec start(Connection.t(), keyword()) :: {:ok, t()} | {:error, term()}
  def start(conn, options \\ []) do
    with {:ok, id} <- @core.start_channel(conn.ref, options) do
      {:ok, new(conn, id)}
    end
  end

  defp new(conn, id) do
    %__MODULE__{connection: conn, id: id}
  end

  @spec stop(t()) :: :ok
  def stop(chan) do
    @core.stop_channel(chan.id)
  end

  @spec mkdir(t(), binary(), timeout()) :: :ok | {:error, term()}
  def mkdir(chan, name, timeout \\ :infinity) do
    @core.make_dir(chan.id, name, timeout)
  end

  @spec open(t(), binary(), [:read | :write | :append | :binary | :raw], timeout()) ::
          {:ok, handle()} | {:error, term()}
  def open(chan, name, mode, timeout \\ :infinity) do
    @core.open(chan.id, name, mode, timeout)
  end

  @spec close(t(), handle(), timeout()) :: :ok | {:error, term()}
  def close(chan, handle, timeout \\ :infinity) do
    @core.close(chan.id, handle, timeout)
  end

  @spec write(t(), handle(), iodata(), timeout()) :: :ok | {:error, term()}
  def write(chan, handle, data, timeout \\ :infinity) do
    @core.write(chan.id, handle, data, timeout)
  end
end
