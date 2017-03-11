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
  :ok = SSHKit.SCP.Upload.transfer(conn, ".", "/home/code/sshkit", recursive: true)
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

    ini = {:next, Path.dirname(local), [[Path.basename(local)]], []}

    handler = fn message, state ->
      case message do
        {:data, _, 0, <<1, data :: binary>>} -> warning(options, state, data)
        {:data, _, 0, <<2, data :: binary>>} -> fatal(options, state, data)
        {:data, _, 0, <<0>>} ->
          case state do
            {:next, cwd, stack, errs} -> next(options, cwd, stack, errs)
            {:directory, name, stat, cwd, stack, errs} -> directory(options, name, stat, cwd, stack, errs)
            {:regular, name, stat, cwd, stack, errs} -> regular(options, name, stat, cwd, stack, errs)
            {:write, name, stat, cwd, stack, errs} -> write(options, name, stat, cwd, stack, errs)
          end
        {:data, _, 0, data} ->
          case state do
            {:warning, state, buffer} -> warning(options, state, buffer <> data)
            {:fatal, state, buffer} -> fatal(options, state, buffer <> data)
          end
        {:exit_status, _, status} -> exited(options, state, status)
        {:eof, _} -> eof(options, state)
        {:closed, _} -> closed(options, state)
      end
    end

    SSHKit.SSH.run(connection, command, timeout: timeout, acc: {:cont, ini}, fun: handler)
  end

  defp next(_, _, [], errs) do
    {:cont, :eof, {:done, nil, errs}}
  end

  defp next(_, cwd, [[] | dirs], errs) do
    {:cont, 'E\n', {:next, Path.dirname(cwd), dirs, errs}}
  end

  defp next(options, cwd, [[name | rest] | dirs], errs) do
    path = Path.join(cwd, name)
    stat = File.stat!(path, time: :posix)

    stack = case stat.type do
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
    {:halt, {:error, "SCP exited before completing the transfer (#{status}): #{Enum.join(errs, ", ")}"}}
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

  defp warning(_, {name, cwd, stack, errs} = state, buffer) do
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
    Bitwise.band(value, 0o7777)
    |> Integer.to_string(8)
    |> String.rjust(4, ?0)
  end
end
