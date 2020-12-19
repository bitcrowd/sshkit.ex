defmodule SSHKit.Download do
  @moduledoc """
  TODO
  """

  defstruct [:source, :target, :options, :cwd, :stack, :channel]

  def init(source, target, options \\ []) do
    %__MODULE__{source: source, target: Path.expand(target), options: options}
  end

  def start(%__MODULE__{} = download, connection) do
  end

  def stop(%__MODULE__{channel: nil} = download), do: {:ok, download}
  def stop(%__MODULE__{channel: channel} = download) do
    with :ok <- :ssh_sftp.stop_channel(channel) do
      {:ok, %{download | channel: nil}}
    end
  end

  def continue(%__MODULE__{stack: []} = download) do
    {:ok, download}
  end

  def loop(%__MODULE__{stack: []} = download) do
    {:ok, download}
  end

  def loop(%__MODULE__{} = download) do
    case continue(download) do
      {:ok, download} ->
        loop(download)

      error ->
        error
    end
  end

  def done?(%__MODULE__{stack: []}), do: true
  def done?(%__MODULE__{}), do: false
end
