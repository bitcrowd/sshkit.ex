defmodule SSHKit.Upload do
  @moduledoc """
  TODO
  """

  defstruct [:source, :target, :options, :cwd, :stack, :channel]

  def init(source, target, options \\ []) do
    %__MODULE__{source: Path.expand(source), target: target, options: options}
  end

  def start(%__MODULE__{} = upload, connection) do
    with {:ok, upload} <- prepare(upload) do
      {:ok, channel} = :ssh_sftp.start_channel(connection.ref) # accepts options like timeout… http://erlang.org/doc/man/ssh_sftp.html#start_channel-1
      {:ok, %{upload | channel: channel}}
    end
  end

  defp prepare(%__MODULE__{source: source, options: options} = upload) do
    # TODO: Support globs, https://hexdocs.pm/elixir/Path.html#wildcard/2
    if !Keyword.get(options, :recursive, false) && File.dir?(source) do
      {:error, "Option :recursive not specified, but local file is a directory (#{source})"} # TODO: Better error
    else
      {:ok, %{upload | cwd: Path.dirname(source), stack: [[Path.basename(source)]]}}
    end
  end

  def stop(%__MODULE__{channel: nil} = upload), do: {:ok, upload}
  def stop(%__MODULE__{channel: channel} = upload) do
    with :ok <- :ssh_sftp.stop_channel(channel) do
      {:ok, %{upload | channel: nil}}
    end
  end

  # TODO: Handle unstarted uploads w/o channel, cwd, stack… and provide helpful error?

  def continue(%__MODULE__{stack: []} = upload) do
    {:ok, upload}
  end

  def continue(%__MODULE__{stack: [[] | paths]} = upload) do
    {:ok, %{upload | cwd: Path.dirname(upload.cwd), stack: paths}}
  end

  def continue(%__MODULE__{stack: [[name | rest] | paths]} = upload) do
    path = Path.join(upload.cwd, name)
    relpath = Path.relative_to(path, Path.expand(upload.source))
    relpath = if relpath == path, do: ".", else: relpath

    remote =
      upload.target
      |> Path.join(relpath)
      |> Path.expand()

    with {:ok, stat} <- File.stat(path, time: :posix) do
      # TODO: Set timestamps… if :preserve option is true, http://erlang.org/doc/man/ssh_sftp.html#write_file_info-3

      channel = upload.channel

      case stat.type do
        :directory ->
          # TODO: Timeouts
          :ok = :ssh_sftp.make_dir(channel, remote)
          {:ok, names} = File.ls(path)
          {:ok, %{upload | cwd: path, stack: [names | [rest | paths]]}}

        :regular ->
          # TODO: Timeouts
          {:ok, handle} = :ssh_sftp.open(channel, remote, [:write, :binary])

          path
          |> File.stream!([], 16_384)
          |> Stream.each(fn data -> :ok = :ssh_sftp.write(channel, handle, data) end)
          |> Stream.run()

          :ok = :ssh_sftp.close(channel, handle)
          {:ok, %{upload | stack: [rest | paths]}}

        :symlink ->
          nil

        _ ->
          {:error, {:unkown_file_type, path}}
      end
    end
  end

  # TODO: Make `loop` return a stream? Possibly rename to "stream" then
  def loop(%__MODULE__{stack: []}) do
    :ok
  end

  def loop(%__MODULE__{} = upload) do
    case continue(upload) do
      {:ok, upload} ->
        loop(upload)

      error ->
        error
    end
  end

  def done?(%__MODULE__{stack: []}), do: true
  def done?(%__MODULE__{}), do: false
end
