defmodule SSHKit.SCP.Upload do
  require Bitwise

  alias SSHKit.SCP.Command

  @doc """
  Uploads a local file or directory to a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  :ok = SSHKit.SCP.Upload.transfer(conn, '.', '/home/code/sshkit', recursive: true)
  ```
  """
  def transfer(connection, local, remote, options \\ []) do
    recursive = Keyword.get(options, :recursive, false)
    local = Path.expand(local)

    if !recursive && File.dir?(local) do
      {:error, "SCP option :recursive not specified, but local file is a directory (#{local})"}
    else
      start(connection, local, remote, options)
    end
  end

  defp start(connection, local, remote, options) do
    timeout = Keyword.get(options, :timeout, :infinity)

    command = Command.build(:upload, remote, options)

    ini = {:next, Path.dirname(local), [[Path.basename(local)]]}

    handler = fn message, state ->
      case message do
        {:data, _, 0, <<0>>} ->
          case state do
            {:next, cwd, stack} -> next(options, cwd, stack)
            {:directory, name, stat, cwd, stack} -> directory(options, name, stat, cwd, stack)
            {:regular, name, stat, cwd, stack} -> regular(options, name, stat, cwd, stack)
            {:data, name, stat, cwd, stack} -> data(options, name, stat, cwd, stack)
            {:done, status} -> done(options, status)
          end
        {:data, _, 0, <<1, msg :: binary>>} -> warning(options, state, msg)
        {:data, _, 0, <<2, msg :: binary>>} -> fatal(options, state, msg)
        {:data, _, 0, msg} ->
          case state do
            {:warning, state, buffer} -> warning(options, state, buffer <> msg)
            {:fatal, state, buffer} -> fatal(options, state, buffer <> msg)
          end
        {:exit_status, _, status} -> exited(options, status)
        {:eof, _} -> cont(state)
        {:closed, _} -> cont(state)
      end
    end

    SSHKit.SSH.run(connection, command, timeout: timeout, acc: {:cont, ini}, fun: handler)
  end

  defp next(_, _, []) do
    {:cont, :eof, {:done, nil}}
  end

  defp next(_, cwd, [[] | dirs]) do
    {:cont, 'E\n', {:next, Path.dirname(cwd), dirs}}
  end

  defp next(options, cwd, [[name | rest] | dirs]) do
    path = Path.join(cwd, name)
    stat = File.stat!(path, time: :posix)

    stack = case stat.type do
      :directory -> [File.ls!(path) | [rest | dirs]]
      :regular -> [rest | dirs]
    end

    if Keyword.get(options, :preserve, false) do
      time(options, stat.type, name, stat, cwd, stack)
    else
      case stat.type do
        :directory -> directory(options, name, stat, cwd, stack)
        :regular -> regular(options, name, stat, cwd, stack)
      end
    end
  end

  defp time(_, type, name, stat, cwd, stack) do
    directive = 'T#{stat.mtime} 0 #{stat.atime} 0\n'
    {:cont, directive, {type, name, stat, cwd, stack}}
  end

  defp directory(_, name, stat, cwd, stack) do
    directive = 'D#{modefmt(stat.mode)} 0 #{name}\n'
    {:cont, directive, {:next, Path.join(cwd, name), stack}}
  end

  defp regular(_, name, stat, cwd, stack) do
    directive = 'C#{modefmt(stat.mode)} #{stat.size} #{name}\n'
    {:cont, directive, {:data, name, stat, cwd, stack}}
  end

  defp data(_, name, _, cwd, stack) do
    fs = File.stream!(Path.join(cwd, name), [], 16_384)
    {:cont, Stream.concat(fs, [<<0>>]), {:next, cwd, stack}}
  end

  defp exited(_, status) do
    {:cont, {:done, status}}
  end

  defp done(_, 0) do
    {:cont, :ok}
  end

  defp done(_, status) do
    {:cont, {:error, "SCP exited with a non-zero exit code (#{status})"}}
  end

  defp cont(state) do
    {:cont, state}
  end

  defp warning(options, state, buffer) do
    error(options, :warning, state, buffer)
  end

  defp fatal(options, state, buffer) do
    error(options, :fatal, state, buffer)
  end

  defp error(_, type, state, buffer) do
    if String.last(buffer) == "\n" do
      {:halt, {:error, String.trim(buffer)}}
    else
      {:cont, {type, state, buffer}}
    end
  end

  defp modefmt(value) do
    Bitwise.band(value, 0o7777)
    |> Integer.to_string(8)
    |> String.rjust(4, ?0)
  end
end
