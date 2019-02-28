defmodule SSHKit.SCP.Download do
  @moduledoc """
  TODO
  """

  require Bitwise

  alias SSHKit.SCP.Command
  alias SSHKit.SCP.Directive
  alias SSHKit.SCP.Download
  alias SSHKit.SSH.Channel

  defstruct [:source, :target, :options, channel: nil, state: nil, cwd: nil, stack: nil]

  # TODO: Close channel whenever error is returned and we don't expect the channel to be closed yet.

  @doc """
  TODO
  """
  def init(source, target, options \\ []) do
    %Download{source: source, target: Path.expand(target), options: options}
  end

  @doc """
  TODO
  """
  def start(%Download{} = download, connection) do
    with {:ok, download} <- prepare(download),
         {:ok, download} <- exec(download, connection) do
      ack(download)
    end
  end

  defp prepare(%Download{target: target} = download) do
    {:ok, %{download | state: :cont, cwd: target, stack: []}}
  end

  defp exec(%Download{source: source, options: options} = download, connection) do
    command = Command.build(:download, source, options)

    map_cmd = Keyword.get(options, :map_cmd, &(&1))
    command = map_cmd.(command)

    with {:ok, channel} <- Channel.open(connection) do # TODO: Pass channel open options?
      case Channel.exec(channel, command) do # TODO: Pass channel exec options?
        :success ->
          {:ok, %{download | channel: channel}}

        :failure ->
          {:error, :failure} # TODO: Better error

        err ->
          err
      end
    end
  end

  defp ack(%Download{channel: channel} = download) do
    with :ok <- Channel.send(channel, <<0>>), do: {:ok, download}
  end

  @doc """
  TODO
  """
  def continue(%Download{channel: channel} = download, timeout \\ :infinity) do
    with {:ok, message} <- Channel.recv(channel, timeout), do: process(download, message)
  end

  @doc """
  TODO
  """
  def process(download, message)

  def process(%Download{channel: channel} = download, {:data, channel, 0, data}) do
    case download.state do
      {:recv, _, _} -> next(download, data)
      {:read, _, _} -> read(download, data)
      :cont -> next(%{download | state: {:recv, "", nil}}, data)
    end
  end

  def process(%Download{channel: channel} = download, {:eof, channel}) do
    {:ok, download}
  end

  def process(%Download{channel: channel} = download, {:exit_status, channel, status}) do
    {:ok, %{download | state: {:exited, status}}}
  end

  def process(%Download{channel: channel, stack: stack} = download, {:closed, channel}) do
    case download.state do
      {:exited, 0} when stack == [] ->
        {:ok, %{download | state: :done}}

      {:exited, status} when status != 0 ->
        {:error, "SCP exited with non-zero status (#{status})"} # TODO: Better error

      _ ->
        {:error, "SCP channel closed before completing the transfer"} # TODO: Better error
    end
  end

  defp next(%Download{state: {:recv, buffer, times}} = download, data) do
    buffer = buffer <> data

    if String.last(buffer) == "\n" do
      case Directive.decode(buffer) do
        {:time, mtime, atime} -> time(download, mtime, atime)
        {:directory, mode, name} -> create(download, {:directory, name, mode, times})
        {:regular, mode, size, name} -> create(download, {:regular, name, mode, size, times})
        {:up} -> up(download)
        _ -> {:error, "Invalid SCP directive received: #{buffer}"} # TODO: Better error
      end
    else
      {:ok, %{download | state: {:recv, buffer, times}}}
    end
  end

  defp time(%Download{channel: channel} = download, mtime, atime) do
    with {:ok, download} <- ack(download) do
      {:ok, %{download | state: {:recv, "", {mtime, atime}}}}
    end
  end

  defp create(%Download{channel: channel} = download, {:directory, name, mode, times}) do
    path = Path.join(download.cwd, name)

    # TODO ??
    # path = if File.dir?(path), do: Path.join(path, name), else: path

    stat = case File.stat(path) do
      {:ok, st} -> st
      _ -> nil
    end

    preserve? = Keyword.get(download.options, :preserve, false)
    exists? = stat != nil

    prepare = if exists? do
      &File.chmod(&1, Bitwise.bor(stat.mode, 0o700))
    else
      &File.mkdir(&1)
    end

    mode = if exists? && !preserve?, do: stat.mode, else: mode
    stack = [{:directory, name, mode, times} | download.stack]

    with :ok <- prepare.(path),
         {:ok, download} <- ack(download) do
      {:ok, %{download | state: :cont, cwd: path, stack: stack}}
    end
  end

  defp create(%Download{channel: channel} = download, {:regular, name, mode, size, times}) do
    path = Path.join(download.cwd, name)

    # TODO: Path exists and is dir?
    # path = if File.dir?(path), do: Path.join(path, name), else: path

    stat = case File.stat(path) do
      {:ok, st} -> st
      _ -> nil
    end

    preserve? = Keyword.get(download.options, :preserve, false)
    exists? = stat != nil

    prepare = if exists? do
      &File.chmod(&1, Bitwise.bor(stat.mode, 0o200))
    else
      fn _ -> :ok end
    end

    mode = if exists? && !preserve?, do: stat.mode, else: mode
    stack = [{:regular, name, mode, size, times} | download.stack]

    with :ok <- prepare.(path),
         {:ok, device} <- File.open(path, [:write, :binary]),
         {:ok, download} <- ack(download) do
      {:ok, %{download | state: {:read, device, {0, size}}, stack: stack}}
    end
  end

  defp read(%Download{channel: channel} = download, data) do
    {:read, device, {written, size}} = download.state

    count = min(byte_size(data), size - written)
    <<chunk::binary-size(count), remainder::binary>> = data

    with :ok <- IO.binwrite(device, chunk) do
      written = written + count

      if written == size && remainder == <<0>> do
        [{:regular, name, mode, _, times} | stack] = download.stack
        path = Path.join(download.cwd, name)

        with :ok <- File.close(device),
             :ok <- File.chmod(path, mode),
             :ok <- touch(path, times), # apply times if preserve
             {:ok, download} <- ack(download) do
          {:ok, %{download | state: :cont, stack: stack}}
        end
      else
        {:ok, %{download | state: {:read, device, {written, size}}}}
      end
    end
  end

  defp up(%Download{stack: []} = download) do
    {:error, "Nowhere to go"} # TODO: Error message
  end

  defp up(%Download{channel: channel, stack: [head | stack]} = download) do
    {:directory, name, mode, times} = head

    # TODO: Apply any mode changes and timestamps
    # TODO: Update cwd and stack

    # cwd = Path.dirname(download.cwd)

    with {:ok, download} <- ack(download) do
      {:ok, %{download | state: :cont, cwd: Path.dirname(download.cwd), stack: stack}}
    end
  end

  defp touch(path, {mtime, atime}) do
    :ok # TODO
  end

  defp touch(path, _) do
    :ok
  end

  @doc """
  TODO
  """
  def loop(%Download{} = download) do
    case continue(download) do
      {:ok, download} ->
        if done?(download), do: :ok, else: loop(download)

      err ->
        err
    end
  end

  @doc """
  TODO
  """
  def done?(download)

  def done?(%Download{state: :done}), do: true

  def done?(%Download{state: _}), do: false
end
