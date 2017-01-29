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
          # name = elem(state, 0)
          #
          # args =
          #   state
          #   |> Tuple.delete_at(0)
          #   |> Tuple.to_list
          #   |> Enum.into([channel, options])
          #
          # apply(__MODULE__, name, args)

          case state do
            {:next, cwd, stack} -> next(channel, options, cwd, stack)
            {:directory, name, stat, cwd, stack} -> directory(channel, options, name, stat, cwd, stack)
            {:file, name, stat, cwd, stack} -> file(channel, options, name, stat, cwd, stack)
            {:data, name, stat, cwd, stack} -> data(channel, options, name, stat, cwd, stack)
            {:done, 0} -> done(channel, options, 0)
          end
        {:exit_status, status} -> {:done, status}
        {:eof} -> state
        {:closed} -> state
      end
    end

    SSHKit.SSH.run(connection, command, timeout, ini, handler)
  end

  defp next(channel, _, ".", []) do
    :ok = Channel.eof(channel)
    {:done, nil}
  end

  defp next(channel, _, cwd, [[] | dirs]) do
    :ok = Channel.send(channel, 'E\n')
    {:next, Path.dirname(cwd), dirs}
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
    {type, name, stat, cwd, stack}
  end

  defp directory(channel, _, name, stat, cwd, stack) do
    :ok = Channel.send(channel, 'D#{modefmt(stat.mode)} 0 #{name}\n')
    {:next, Path.join(cwd, name), stack}
  end

  defp file(channel, _, name, stat, cwd, stack) do
    :ok = Channel.send(channel, 'C#{modefmt(stat.mode)} #{stat.size} #{name}\n')
    {:data, name, stat, cwd, stack}
  end

  defp data(channel, _, name, _, cwd, stack) do
    File.stream!(Path.join(cwd, name), [], 16_384)
    |> Enum.each(fn data -> :ok = Channel.send(channel, data) end)

    :ok = Channel.send(channel, <<0>>)

    {:next, cwd, stack}
  end

  defp done(_, _, 0) do
    :ok
  end

  defp modefmt(value) do
    Bitwise.band(value, 0o7777)
    |> Integer.to_string(8)
    |> String.rjust(4, ?0)
  end
end
