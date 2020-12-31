{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

ctx =
  SSHKit.Context.new()
  |> SSHKit.Context.path("/tmp")
  |> SSHKit.Context.user("other")
  |> SSHKit.Context.group("other")

defmodule Xfer do
  # https://github.com/erlang/otp/blob/OTP-23.2.1/lib/ssh/src/ssh.hrl
  def to_binary(data) when is_list(data) do
    :erlang.iolist_to_binary(data)
  catch
    _ -> :unicode.characters_to_binary(data)
  end

  def to_binary(data) when is_binary(data) do
    data
  end
end

:ok =
  with {:ok, chan} <- SSHKit.Channel.open(conn, []) do
    # command = SSHKit.Context.build(ctx, "tar -x")
    command = "tar -x -C #{ctx.path}"
    IO.puts(command)

    case SSHKit.Channel.exec(chan, command) do
      :success ->
        {:ok, tar} = :erl_tar.init(self(), :write, fn
          :position, {_, position} ->
            # IO.write("tar position: #{inspect(position)}")
            {:ok, 0}

          :write, {_, data} ->
            :ok = SSHKit.Channel.send(chan, Xfer.to_binary(data))
            :ok

          :close, _ ->
            :ok = SSHKit.Channel.eof(chan)
            :ok
        end)

        source = "test/fixtures"
        # :ok = :erl_tar.add(tar, to_charlist(source), to_charlist(source))

        with {:ok, names} <- File.ls(source) do
          Enum.each(names, fn name ->
            path = Path.join(source, name)

            with {:ok, stat} <- File.stat(path, time: :posix) do
              IO.puts("#{stat.type}: #{path}")

              :ok = :erl_tar.add(tar, to_charlist(path), to_charlist(path), atime: stat.atime, mtime: stat.mtime, ctime: stat.ctime)
            end
          end)
        end

        :ok = :erl_tar.close(tar)

      :failure ->
        {:error, :failure}

      other ->
        other
    end
  end

:ok = SSHKit.close(conn)
