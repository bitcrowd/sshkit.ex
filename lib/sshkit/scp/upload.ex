defmodule SSHKit.SCP.Upload do
  @moduledoc """
  Helper module used by SSHKit.SCP.upload/4.
  """

  require Bitwise

  alias SSHKit.SCP.Command
  alias SSHKit.SSH

  defstruct [:source, :target, :state, :handler, options: []]

  @doc """
  Uploads a local file or directory to a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  :ok = SSHKit.SCP.Upload.transfer(conn, ".", "/home/code/sshkit", recursive: true)
  ```
  """
  def transfer(connection, source, target, options \\ []) do
    source
    |> init(target, options)
    |> exec(connection)
  end

  @doc """
  Configures the upload of a local file or directory to a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  iex(1)> SSHKit.SCP.Upload.init(".", "/home/code/sshkit", recursive: true)
  %SSHKit.SCP.Upload{
    handler: #Function<1.78222439/2 in SSHKit.SCP.Upload.connection_handler/1>,
    options: [recursive: true],
    source: "/Users/sshkit/code/sshkit.ex",
    state: {:next, "/Users/sshkit/code", [["sshkit.ex"]], []},
    target: "/home/code/sshkit"
  }
  ```
  """
  def init(source, target, options \\ []) do
    source = Path.expand(source)
    state = {:next, Path.dirname(source), [[Path.basename(source)]], []}
    handler = connection_handler(options)
    %__MODULE__{source: source, target: target, state: state, handler: handler, options: options}
  end

  @doc """
  Executes an upload of a local file or directory to a remote host.

  ## Example

  ```
  :ok = SSHKit.SCP.Upload.exec(upload, conn)
  ```
  """
  def exec(upload = %{source: source, options: options}, connection) do
    recursive = Keyword.get(options, :recursive, false)

    if !recursive && File.dir?(source) do
      {:error, "SCP option :recursive not specified, but local file is a directory (#{source})"}
    else
      start(upload, connection)
    end
  end

  defp start(%{target: target, state: state, handler: handler, options: options}, connection) do
    timeout = Keyword.get(options, :timeout, :infinity)
    map_cmd = Keyword.get(options, :map_cmd, & &1)
    command = map_cmd.(Command.build(:upload, target, options))
    ssh = Keyword.get(options, :ssh, SSH)
    ssh.run(connection, command, timeout: timeout, acc: {:cont, state}, fun: handler)
  end

  @normal 0
  @warning 1
  @fatal 2
  defp connection_handler(options) do
    fn message, state ->
      case message do
        {:data, _, 0, <<@warning, data::binary>>} ->
          warning(options, state, data)

        {:data, _, 0, <<@fatal, data::binary>>} ->
          fatal(options, state, data)

        {:data, _, 0, <<@normal>>} ->
          handle_data(state, options)

        {:data, _, 0, data} ->
          handle_error_data(state, options, data)

        {:exit_status, _, status} ->
          exited(options, state, status)

        {:eof, _} ->
          eof(options, state)

        {:closed, _} ->
          closed(options, state)
      end
    end
  end

  defp handle_data(state, options) do
    case state do
      {:next, cwd, stack, errs} ->
        next(options, cwd, stack, errs)

      {:directory, name, stat, cwd, stack, errs} ->
        directory(options, name, stat, cwd, stack, errs)

      {:regular, name, stat, cwd, stack, errs} ->
        regular(options, name, stat, cwd, stack, errs)

      {:write, name, stat, cwd, stack, errs} ->
        write(options, name, stat, cwd, stack, errs)
    end
  end

  defp handle_error_data(state, options, data) do
    case state do
      {:warning, state, buffer} -> warning(options, state, buffer <> data)
      {:fatal, state, buffer} -> fatal(options, state, buffer <> data)
    end
  end

  defp next(_, _, [[]], errs) do
    {:cont, :eof, {:done, nil, errs}}
  end

  defp next(_, cwd, [[] | dirs], errs) do
    {:cont, 'E\n', {:next, Path.dirname(cwd), dirs, errs}}
  end

  defp next(options, cwd, [[name | rest] | dirs], errs) do
    path = Path.join(cwd, name)
    stat = File.stat!(path, time: :posix)

    stack =
      case stat.type do
        :directory -> [File.ls!(path) | [rest | dirs]]
        :regular -> [rest | dirs]
      end

    if Keyword.get(options, :preserve, false) do
      time(options, stat.type, name, stat, cwd, stack, errs)
    else
      case stat.type do
        :directory -> directory(options, name, stat, cwd, stack, errs)
        :regular -> regular(options, name, stat, cwd, stack, errs)
      end
    end
  end

  defp time(_, type, name, stat, cwd, stack, errs) do
    directive = 'T#{stat.mtime} 0 #{stat.atime} 0\n'
    {:cont, directive, {type, name, stat, cwd, stack, errs}}
  end

  defp directory(_, name, stat, cwd, stack, errs) do
    directive = 'D#{modefmt(stat.mode)} 0 #{name}\n'
    {:cont, directive, {:next, Path.join(cwd, name), stack, errs}}
  end

  defp regular(_, name, stat, cwd, stack, errs) do
    directive = 'C#{modefmt(stat.mode)} #{stat.size} #{name}\n'
    {:cont, directive, {:write, name, stat, cwd, stack, errs}}
  end

  defp write(_, name, _, cwd, stack, errs) do
    fs = File.stream!(Path.join(cwd, name), [], 16_384)
    {:cont, Stream.concat(fs, [<<0>>]), {:next, cwd, stack, errs}}
  end

  defp exited(_, {:done, nil, errs}, status) do
    {:cont, {:done, status, errs}}
  end

  defp exited(_, {_, _, _, errs}, status) do
    {:halt,
     {:error, "SCP exited before completing the transfer (#{status}): #{Enum.join(errs, ", ")}"}}
  end

  defp eof(_, state) do
    {:cont, state}
  end

  defp closed(_, {:done, 0, _}) do
    {:cont, :ok}
  end

  defp closed(_, {:done, status, errs}) do
    {:cont, {:error, "SCP exited with non-zero exit code #{status}: #{Enum.join(errs, ", ")}"}}
  end

  defp closed(_, _) do
    {:cont, {:error, "SCP channel closed before completing the transfer"}}
  end

  defp warning(_, state = {name, cwd, stack, errs}, buffer) do
    if String.last(buffer) == "\n" do
      {:cont, {name, cwd, stack, errs ++ [String.trim(buffer)]}}
    else
      {:cont, {:warning, state, buffer}}
    end
  end

  defp fatal(_, state, buffer) do
    if String.last(buffer) == "\n" do
      {:halt, {:error, String.trim(buffer)}}
    else
      {:cont, {:fatal, state, buffer}}
    end
  end

  defp modefmt(value) do
    value
    |> Bitwise.band(0o7777)
    |> Integer.to_string(8)
    |> String.pad_leading(4, "0")
  end
end
