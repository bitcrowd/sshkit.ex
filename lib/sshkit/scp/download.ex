defmodule SSHKit.SCP.Download do
  require Bitwise

  alias SSHKit.SCP.Command

  @doc """
  Downloads a file or directory from a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  :ok = SSHKit.SCP.Download.transfer(conn, "/home/code/sshkit", "downloads", recursive: true)
  ```
  """
  def transfer(connection, remote, local, options \\ []) do
    start(connection, remote, Path.expand(local), options)
  end

  defp start(connection, remote, local, options) do
    timeout = Keyword.get(options, :timeout, :infinity)

    command = Command.build(:download, remote, options)

    ini = {:next, local, [], %{}, <<>>, []}

    handler = fn message, state ->
      case message do
        {:data, _, 0, data} ->
          case state do
            {:next, path, stack, attrs, buffer, errs} -> next(options, path, stack, attrs, buffer <> data, errs)
            {:read, path, stack, attrs, buffer, errs} -> read(options, path, stack, attrs, buffer <> data, errs)
            {:warning, state, buffer} -> warning(options, state, buffer <> data)
            {:fatal, state, buffer} -> fatal(options, state, buffer <> data)
          end
        {:exit_status, _, status} -> exited(options, state, status)
        {:eof, _} -> eof(options, state)
        {:closed, _} -> closed(options, state)
     end
    end

    SSHKit.SSH.run(connection, command, timeout: timeout, acc: {:cont, <<0>>, ini}, fun: handler)
  end

  defp next(options, path, stack, attrs, buffer, errs) do
    if String.last(buffer) == "\n" do
      case dirparse(buffer) do
        {"T", mtime, _, atime, _} -> time(options, path, stack, attrs, mtime, atime, errs)
        {"C", mode, len, name} -> regular(options, path, stack, attrs, mode, len, name, errs)
        {"D", mode, _, name} -> directory(options, path, stack, attrs, mode, name, errs)
        {"E"} -> up(options, path, stack, errs)
        _ -> {:halt, {:error, "Invalid SCP directive received: #{buffer}"}}
      end
    else
      {:cont, {:next, stack, buffer, attrs}}
    end
  end

  defp time(_, path, stack, attrs, mtime, atime, errs) do
    attrs = Map.merge(attrs, %{atime: atime, mtime: mtime})
    {:cont, <<0>>, {:next, path, stack, attrs, <<>>, errs}}
  end

  defp directory(options, path, stack, attrs, mode, name, errs) do
    target = if File.dir?(path), do: Path.join(path, name), else: path

    preserve? = Keyword.get(options, :preserve, false)
    exists? = File.exists?(target)

    stat = if exists?, do: File.stat!(target), else: nil

    if exists? do
      :ok = File.chmod!(target, Bitwise.bor(stat.mode, 0o700))
    else
      :ok = File.mkdir!(target)
    end

    mode = if exists? && !preserve?, do: stat.mode, else: mode
    attrs = Map.put(attrs, :mode, mode)

    {:cont, <<0>>, {:next, target, [attrs | stack], %{}, <<>>, errs}}
  end

  defp regular(options, path, stack, attrs, mode, length, name, errs) do
    target = if File.dir?(path), do: Path.join(path, name), else: path

    preserve? = Keyword.get(options, :preserve, false)
    exists? = File.exists?(target)

    stat = if exists?, do: File.stat!(target), else: nil

    if exists? do
      :ok = File.chmod!(target, Bitwise.bor(stat.mode, 0o200))
    end

    device = File.open!(target, [:write, :binary])

    mode = if exists? && !preserve?, do: stat.mode, else: mode

    attrs =
      attrs
      |> Map.put(:mode, mode)
      |> Map.put(:device, device)
      |> Map.put(:length, length)
      |> Map.put(:written, 0)

    {:cont, <<0>>, {:read, target, stack, attrs, <<>>, errs}}
  end

  defp read(options, path, stack, attrs, buffer, errs) do
    %{device: device, length: length, written: written} = attrs

    {buffer, written} =
      if written < length do
        count = min(byte_size(buffer), length - written)
        <<chunk::binary-size(count), rest::binary>> = buffer
        :ok = IO.binwrite(device, chunk)
        {rest, written + count}
      else
        {buffer, written}
      end

    if written == length && buffer == <<0>> do
      :ok = File.close(device)

      :ok = File.chmod!(path, attrs[:mode])

      if Keyword.get(options, :preserve, false) do
        :ok = touch!(path, attrs[:atime], attrs[:mtime])
      end

      {:cont, <<0>>, {:next, Path.dirname(path), stack, %{}, <<>>, errs}}
    else
      {:cont, {:read, path, stack, Map.put(attrs, :written, written), <<>>, errs}}
    end
  end

  defp up(options, path, [attrs | rest], errs) do
    :ok = File.chmod!(path, attrs[:mode])

    if Keyword.get(options, :preserve, false) do
      :ok = touch!(path, attrs[:atime], attrs[:mtime])
    end

    {:cont, <<0>>, {:next, Path.dirname(path), rest, %{}, <<>>, errs}}
  end

  defp exited(_, {_, _, [], _, _, errs}, status) do
    {:cont, {:done, status, errs}}
  end

  defp exited(_, {_, _, _, _, _, errs}, status) do
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

  defp warning(_, {name, path, stack, attrs, buf, errs} = state, buffer) do
    if String.last(buffer) == "\n" do
      {:cont, {name, path, stack, attrs, buf, errs ++ [String.trim(buffer)]}}
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

  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  defp touch!(path, atime, mtime) do
    atime = :calendar.gregorian_seconds_to_datetime(@epoch + atime)
    mtime = :calendar.gregorian_seconds_to_datetime(@epoch + mtime)
    :ok = :file.change_time(path, atime, mtime)
  end

  @tfmt ~S"(T)(0|[1-9]\d*) (0|[1-9]\d{0,5}) (0|[1-9]\d*) (0|[1-9]\d{0,5})"
  @ffmt ~S"(C|D)([0-7]{4}) (0|[1-9]\d*) ([^/]+)"
  @efmt ~S"(E)"

  @dfmt ~r/\A(?|#{@efmt}|#{@tfmt}|#{@ffmt})\n\z/

  defp dirparse(value) do
    case Regex.run(@dfmt, value, capture: :all_but_first) do
      ["T", mtime, mtus, atime, atus] -> {"T", dec(mtime), dec(mtus), dec(atime), dec(atus)}
      [chr, _, _, name] when chr in ["C", "D"] and name in ["/", "..", "."] -> nil
      ["C", mode, len, name] -> {"C", oct(mode), dec(len), name}
      ["D", mode, len, name] -> {"D", oct(mode), dec(len), name}
      ["E"] -> {"E"}
      nil -> nil
    end
  end

  defp int(value, base), do: String.to_integer(value, base)
  defp dec(value), do: int(value, 10)
  defp oct(value), do: int(value, 8)
end
