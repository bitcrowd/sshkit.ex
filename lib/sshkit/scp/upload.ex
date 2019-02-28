defmodule SSHKit.SCP.Upload do
  @moduledoc """
  TODO
  """

  alias SSHKit.SCP.Command
  alias SSHKit.SCP.Directive
  alias SSHKit.SCP.Upload
  alias SSHKit.SSH.Channel

  defstruct [:source, :target, :options, channel: nil, state: nil, cwd: nil, stack: nil, warnings: []]

  # TODO: Close channel whenever error is returned and we don't expect the channel to be closed yet.

  @doc """
  TODO
  """
  def init(source, target, options \\ []) do
    %Upload{source: Path.expand(source), target: target, options: options}
  end

  def start(%Upload{} = upload, connection) do
    with {:ok, upload} <- prepare(upload), do: exec(upload, connection)
  end

  defp prepare(%Upload{source: source, options: options} = upload) do
    if !Keyword.get(options, :recursive, false) && File.dir?(source) do
      {:error, "SCP option :recursive not specified, but local file is a directory (#{source})"} # TODO: Better error
    else
      {:ok, %{upload | state: :cont, cwd: Path.dirname(source), stack: [[Path.basename(source)]]}}
    end
  end

  defp exec(%Upload{target: target, options: options} = upload, connection) do
    command = Command.build(:upload, target, options)

    map_cmd = Keyword.get(options, :map_cmd, &(&1))
    command = map_cmd.(command)

    with {:ok, channel} <- Channel.open(connection) do # TODO: Pass channel open options?
      case Channel.exec(channel, command) do # TODO: Pass channel exec options?
        :success ->
          {:ok, %{upload | channel: channel}}

        :failure ->
          {:error, :failure} # TODO: Better error

        err ->
          err
      end
    end
  end

  @doc """
  TODO
  """
  def continue(%Upload{channel: channel} = upload, timeout \\ :infinity) do
    with {:ok, message} <- Channel.recv(channel, timeout), do: process(upload, message)
  end

  @doc """
  TODO
  """
  def process(upload, message)

  @normal 0

  def process(%Upload{channel: channel} = upload, {:data, channel, 0, <<@normal>>}) do
    case upload.state do
      {:directory, _, _} -> create(upload)
      {:regular, _, _} -> create(upload)
      {:write, _, _} -> write(upload)
      :cont -> next(upload)
    end
  end

  @warning 1

  def process(%Upload{channel: channel} = upload, {:data, channel, 0, <<@warning, data::binary>>}) do
    warning(%{upload | state: {:warning, upload.state, ""}}, data)
  end

  @fatal 2

  def process(%Upload{channel: channel} = upload, {:data, channel, 0, <<@fatal, data::binary>>}) do
    fatal(%{upload | state: {:fatal, ""}}, data)
  end

  def process(%Upload{channel: channel} = upload, {:data, channel, 0, <<data::binary>>}) do
    case upload.state do
      {:warning, _, _} -> warning(upload, data)
      {:fatal, _} -> fatal(upload, data)
    end
  end

  def process(%Upload{channel: channel} = upload, {:eof, channel}) do
    {:ok, upload}
  end

  def process(%Upload{channel: channel} = upload, {:exit_status, channel, status}) do
    {:ok, %{upload | state: {:exited, status}}}
  end

  def process(%Upload{channel: channel, stack: stack} = upload, {:closed, channel}) do
    case upload.state do
      {:exited, 0} when stack == [] ->
        {:ok, %{upload | state: :done}}

      {:exited, status} when status != 0 ->
        {:error, "SCP exited with non-zero status (#{status})"} # TODO: Better error

      _ ->
        {:error, "SCP channel closed before completing the transfer"} # TODO: Better error
    end
  end

  defp next(%Upload{channel: channel, stack: [[]]} = upload) do
    with :ok <- Channel.eof(channel) do
      {:ok, %{upload | stack: []}}
    end
  end

  defp next(%Upload{channel: channel, stack: [[] | paths]} = upload) do
    with :ok <- Channel.send(channel, Directive.encode(:up)) do
      {:ok, %{upload | cwd: Path.dirname(upload.cwd), stack: paths}}
    end
  end

  defp next(%Upload{stack: [[name | rest] | paths]} = upload) do
    path = Path.join(upload.cwd, name)

    with {:ok, stat} <- File.stat(path, time: :posix) do
      upload = %{upload | state: {stat.type, name, stat}, stack: [rest | paths]}

      if Keyword.get(upload.options, :preserve, false) do
        time(upload)
      else
        create(upload)
      end
    end
  end

  defp time(%Upload{channel: channel, state: {_, _, stat}} = upload) do
    with :ok <- Channel.send(channel, Directive.encode(:time, stat.mtime, stat.atime)) do
      {:ok, upload}
    end
  end

  defp create(%Upload{channel: channel, state: {:directory, name, stat}} = upload) do
    with :ok <- Channel.send(channel, Directive.encode(:directory, stat.mode, name)) do
      cwd = Path.join(upload.cwd, name)

      with {:ok, names} <- File.ls(cwd) do
        {:ok, %{upload | state: :cont, cwd: cwd, stack: [names | upload.stack]}}
      end
    end
  end

  defp create(%Upload{channel: channel, state: {:regular, name, stat}} = upload) do
    with :ok <- Channel.send(channel, Directive.encode(:regular, stat.mode, stat.size, name)) do
      {:ok, %{upload | state: {:write, name, stat}}}
    end
  end

  defp create(%Upload{state: {type, name, _}} = upload) do
    {:error, "Unhandled file type \"#{type}\" (#{Path.join(upload.cwd, name)})"} # TODO: Better error
  end

  defp write(%Upload{channel: channel, state: {_, name, _}} = upload) do
    fs = File.stream!(Path.join(upload.cwd, name), [], 16_384)
    with :ok <- Channel.send(channel, Stream.concat(fs, [<<0>>])) do
      {:ok, %{upload | state: :cont}}
    end
  end

  defp warning(%Upload{state: {:warning, snapshot, buffer}, warnings: warnings} = upload, data) do
    buffer = buffer <> data

    if String.last(buffer) == "\n" do
      {:ok, %{upload | state: snapshot, warnings: warnings ++ [String.trim(buffer)]}}
    else
      {:ok, %{upload | state: {:warning, snapshot, buffer}}}
    end
  end

  defp fatal(%Upload{state: {:fatal, buffer}} = upload, data) do
    buffer = buffer <> data

    if String.last(buffer) == "\n" do
      {:error, {:fatal, String.trim(buffer)}} # TODO: Better error?
    else
      {:ok, %{upload | state: {:fatal, buffer}}}
    end
  end

  @doc """
  """
  def loop(%Upload{} = upload) do
    case continue(upload) do
      {:ok, upload} ->
        if done?(upload), do: :ok, else: loop(upload)

      err ->
        err
    end
  end

  @doc """
  TODO
  """
  def done?(upload)

  def done?(%Upload{state: :done}), do: true

  def done?(%Upload{state: _}), do: false
end
