defmodule SSHKit.SCP.Upload do
  require Bitwise

  alias SSHKit.SCP.Command
  alias SSHKit.SSH.Channel

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
    timeout = Keyword.get(options, :timeout, :infinity)

    command = Command.build(:upload, remote, options)

    ini = {:next, ".", [[local]]}

    handler = fn channel, message, state ->
      case message do
        {:data, 0, <<0>>} ->
          case state do
            {:next, cwd, stack} -> next(channel, options, cwd, stack)
            {:directory, name, stat, cwd, stack} -> directory(channel, options, name, stat, cwd, stack)
            {:file, name, stat, cwd, stack} -> file(channel, options, name, stat, cwd, stack)
            {:data, name, stat, cwd, stack} -> data(channel, options, name, stat, cwd, stack)
            {:done, status} -> done(channel, options, status)
          end
        {:data, 0, <<1, msg :: binary>>} -> warning(channel, options, state, msg)
        {:data, 0, <<2, msg :: binary>>} -> fatal(channel, options, state, msg)
        {:data, 0, msg} ->
          case state do
            {:warning, state, buffer} -> warning(channel, options, state, buffer <> msg)
            {:fatal, state, buffer} -> fatal(channel, options, state, buffer <> msg)
          end
        {:exit_status, status} -> exited(channel, options, status)
        {:eof} -> state
        {:closed} -> state
      end
    end

    SSHKit.SSH.run(connection, command, timeout, ini, handler)
  end

  defp next(channel, _, ".", []) do
    :ok = Channel.eof(channel)
    {:cont, {:done, nil}}
  end

  defp next(channel, _, cwd, [[] | dirs]) do
    :ok = Channel.send(channel, 'E\n')
    {:cont, {:next, Path.dirname(cwd), dirs}}
  end

  defp next(channel, options, cwd, [[name | rest] | dirs]) do
    path = Path.join(cwd, name)
    stat = File.stat!(path, time: :posix)

    case stat.type do
      :directory -> directory(channel, options, name, stat, cwd, [File.ls!(path) | [rest | dirs]])
      :regular -> file(channel, options, name, stat, cwd, [rest | dirs])
    end
  end

  defp time(channel, _, type, name, stat, cwd, stack) do
    :ok = Channel.send(channel, 'T#{stat.mtime} 0 #{stat.atime} 0\n')
    {:cont, {type, name, stat, cwd, stack}}
  end

  defp directory(channel, _, name, stat, cwd, stack) do
    :ok = Channel.send(channel, 'D#{modefmt(stat.mode)} 0 #{name}\n')
    {:cont, {:next, Path.join(cwd, name), stack}}
  end

  defp file(channel, _, name, stat, cwd, stack) do
    :ok = Channel.send(channel, 'C#{modefmt(stat.mode)} #{stat.size} #{name}\n')
    {:cont, {:data, name, stat, cwd, stack}}
  end

  defp data(channel, _, name, _, cwd, stack) do
    File.stream!(Path.join(cwd, name), [], 16_384)
    |> Enum.each(fn data -> :ok = Channel.send(channel, data) end)

    :ok = Channel.send(channel, <<0>>)

    {:cont, {:next, cwd, stack}}
  end

  defp exited(_, _, status) do
    {:cont, {:done, status}}
  end

  defp done(_, _, 0) do
    {:cont, :ok}
  end

  defp done(_, _, status) do
    {:cont, {:error, "SCP exited with a non-zero exit code (#{status})"}}
  end

  defp warning(channel, options, state, buffer) do
    error(channel, options, :warning, state, buffer)
  end

  defp fatal(channel, options, state, buffer) do
    error(channel, options, :fatal, state, buffer)
  end

  defp error(_, _, type, state, buffer) do
    if String.last(buffer) == "\n" do
      {:stop, {:error, String.trim(buffer)}}
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
