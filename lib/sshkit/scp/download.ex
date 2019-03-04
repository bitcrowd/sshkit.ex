defmodule SSHKit.SCP.Download do
  @moduledoc false

  require Bitwise

  alias SSHKit.SCP.Command
  alias SSHKit.SSH

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
  def transfer(connection, source, target, options \\ []) do
    start(connection, source, Path.expand(target), options)
  end

  defp start(connection, source, target, options) do
    timeout = Keyword.get(options, :timeout, :infinity)
    map_cmd = Keyword.get(options, :map_cmd, &(&1))
    command = map_cmd.(Command.build(:download, source, options))
    handler = connection_handler(options)

    ini = {:next, target, [], %{}, <<>>}
    SSH.run(connection, command, timeout: timeout, acc: {:cont, <<0>>, ini}, fun: handler)
  end

  defp connection_handler(options) do
    fn message, state ->
      case message do
        {:data, _, 0, data} ->
          process_data(state, data, options)
        {:exit_status, _, status} ->
          exited(options, state, status)
        {:eof, _} ->
          eof(options, state)
        {:closed, _} ->
          closed(options, state)
      end
    end
  end

  defp process_data(state, data, options) do
    case state do
      {:next, path, stack, attrs, buffer} ->
        next(options, path, stack, attrs, buffer <> data)
      {:read, path, stack, attrs, buffer} ->
        read(options, path, stack, attrs, buffer <> data)
    end
  end

  defp next(options, path, stack, attrs, buffer) do
    if String.last(buffer) == "\n" do
      case dirparse(buffer) do
        {"T", mtime, _, atime, _} -> time(options, path, stack, attrs, mtime, atime)
        {"C", mode, len, name} -> regular(options, path, stack, attrs, mode, len, name)
        {"D", mode, _, name} -> directory(options, path, stack, attrs, mode, name)
        {"E"} -> up(options, path, stack)
        _ -> {:halt, {:error, "Invalid SCP directive received: #{buffer}"}}
      end
    else
      {:cont, {:next, path, stack, attrs, buffer}}
    end
  end

  defp time(_, path, stack, attrs, mtime, atime) do
    attrs = Map.merge(attrs, %{atime: atime, mtime: mtime})
    {:cont, <<0>>, {:next, path, stack, attrs, <<>>}}
  end

  defp directory(options, path, stack, attrs, mode, name) do
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

    {:cont, <<0>>, {:next, target, [attrs | stack], %{}, <<>>}}
  end

  defp regular(options, path, stack, attrs, mode, length, name) do
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

    {:cont, <<0>>, {:read, target, stack, attrs, <<>>}}
  end

  defp read(options, path, stack, attrs, buffer) do
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

      {:cont, <<0>>, {:next, Path.dirname(path), stack, %{}, <<>>}}
    else
      {:cont, {:read, path, stack, Map.put(attrs, :written, written), <<>>}}
    end
  end

  defp up(options, path, [attrs | rest]) do
    :ok = File.chmod!(path, attrs[:mode])

    if Keyword.get(options, :preserve, false) do
      :ok = touch!(path, attrs[:atime], attrs[:mtime])
    end

    {:cont, <<0>>, {:next, Path.dirname(path), rest, %{}, <<>>}}
  end

  defp exited(_, {_, _, [], _, _}, status) do
    {:cont, {:done, status}}
  end

  defp exited(_, {_, _, _, _, _}, status) do
    {:halt, {:error, "SCP exited before completing the transfer (#{status})"}}
  end

  defp eof(_, state) do
    {:cont, state}
  end

  defp closed(_, {:done, 0}) do
    {:cont, :ok}
  end

  defp closed(_, {:done, status}) do
    {:cont, {:error, "SCP exited with non-zero exit code #{status}"}}
  end

  defp closed(_, _) do
    {:cont, {:error, "SCP channel closed before completing the transfer"}}
  end

  @epoch :calendar.datetime_to_gregorian_seconds({{1970, 1, 1}, {0, 0, 0}})

  defp touch!(path, atime, mtime) do
    atime = :calendar.gregorian_seconds_to_datetime(@epoch + atime)
    mtime = :calendar.gregorian_seconds_to_datetime(@epoch + mtime)
    {:ok, file_info} = File.stat(path)
    :ok = File.write_stat(path, %{file_info| mtime: mtime, atime: atime}, [:posix])
  end

  @tfmt ~S"(T)(0|[1-9]\d*) (0|[1-9]\d{0,5}) (0|[1-9]\d*) (0|[1-9]\d{0,5})"
  @ffmt ~S"(C|D)([0-7]{4}) (0|[1-9]\d*) ([^/]+)"
  @efmt ~S"(E)"

  @dfmt ~r/\A(?|#{@efmt}|#{@tfmt}|#{@ffmt})\n\z/

  defp dirparse(value) do
    case Regex.run(@dfmt, value, capture: :all_but_first) do
      ["T", mtime, mtus, atime, atus] ->
        {"T", dec(mtime), dec(mtus), dec(atime), dec(atus)}
      [chr, _, _, name] when chr in ["C", "D"] and name in ["/", "..", "."] ->
        nil
      ["C", mode, len, name] ->
        {"C", oct(mode), dec(len), name}
      ["D", mode, len, name] ->
        {"D", oct(mode), dec(len), name}
      ["E"] ->
        {"E"}
      nil ->
        nil
    end
  end

  defp int(value, base), do: String.to_integer(value, base)
  defp dec(value), do: int(value, 10)
  defp oct(value), do: int(value, 8)
end
