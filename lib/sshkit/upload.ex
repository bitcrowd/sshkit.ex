defmodule SSHKit.Upload do
  @moduledoc """
  TODO
  """

  alias SSHKit.SFTP.Channel

  defstruct [:source, :target, :options, :cwd, :stack, :channel]

  @type t() :: %__MODULE__{}

  def init(source, target, options \\ []) do
    %__MODULE__{source: Path.expand(source), target: target, options: options}
  end

  def start(%__MODULE__{options: options} = upload, conn) do
    # accepts options like timeout… http://erlang.org/doc/man/ssh_sftp.html#start_channel-1
    start_options =
      options
      |> Keyword.get(:start, [])
      |> Keyword.put_new(:timeout, Keyword.get(options, :timeout, :infinity))

    with {:ok, upload} <- prepare(upload),
         {:ok, chan} <- Channel.start(conn, start_options) do
      {:ok, %{upload | channel: chan}}
    end
  end

  defp prepare(%__MODULE__{source: source, options: options} = upload) do
    if !Keyword.get(options, :recursive, false) && File.dir?(source) do
      # TODO: Better error
      {:error, "Option :recursive not specified, but local file is a directory (#{source})"}
    else
      {:ok, %{upload | cwd: Path.dirname(source), stack: [[Path.basename(source)]]}}
    end
  end

  def stop(%__MODULE__{channel: nil} = upload), do: {:ok, upload}

  def stop(%__MODULE__{channel: chan} = upload) do
    with :ok <- Channel.stop(chan) do
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
    relpath = Path.relative_to(path, upload.source)
    relpath = if relpath == path, do: ".", else: relpath

    remote =
      upload.target
      |> Path.join(relpath)
      |> Path.expand()

    with {:ok, stat} <- File.stat(path, time: :posix) do
      # TODO: Set timestamps… if :preserve option is true, http://erlang.org/doc/man/ssh_sftp.html#write_file_info-3

      chan = upload.channel

      case stat.type do
        :directory ->
          # TODO: Timeouts
          with :ok <- Channel.mkdir(chan, remote),
               {:ok, names} <- File.ls(path) do
            {:ok, %{upload | cwd: path, stack: [names | [rest | paths]]}}
          end

        :regular ->
          # TODO: Timeouts
          with {:ok, handle} <- Channel.open(chan, remote, [:write, :binary]),
               :ok <- write(path, chan, handle),
               :ok <- Channel.close(chan, handle) do
            {:ok, %{upload | stack: [rest | paths]}}
          end

        :symlink ->
          # TODO: http://erlang.org/doc/man/ssh_sftp.html#make_symlink-3
          raise "not yet implemented"

        _ ->
          {:error, {:unkown_file_type, path}}
      end
    end
  end

  defp write(path, chan, handle) do
    path
    |> File.stream!([], 65_536)
    |> Stream.map(fn data -> Channel.write(chan, handle, data) end)
    |> Enum.find(:ok, &(&1 != :ok))
  end

  def done?(%{stack: []}), do: true
  def done?(%{}), do: false
end
