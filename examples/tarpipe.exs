{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

ctx =
  SSHKit.Context.new()
  |> SSHKit.Context.path("/tmp")
  # |> SSHKit.Context.user("other")
  # |> SSHKit.Context.group("other")
  |> SSHKit.Context.umask("0077")

defmodule TP do
  def upload!(conn, source, dest, opts \\ []) do
    ctx = Keyword.get(opts, :context, SSHKit.Context.new())

    Stream.resource(
      fn ->
        owner = self()

        tarpipe = spawn(fn ->
          {:ok, chan} = SSHKit.Channel.open(conn, [])
          command = SSHKit.Context.build(ctx, "tar -x")
          :success = SSHKit.Channel.exec(chan, command)

          # TODO: What if command immediately exits or does not exist?
          # IO.inspect(SSHKit.Channel.recv(chan, 1000))

          {:ok, tar} = :erl_tar.init(chan, :write, fn
            :position, {^chan, position} ->
              # IO.inspect(position, label: "position")
              {:ok, 0}

            :write, {^chan, data} ->
              # TODO: Send data in chunks based on channel window size?
              IO.inspect(data, label: "write")
              # In case of failing upload, check command output:
              # IO.inspect(SSHKit.Channel.recv(chan, 0))
              chunk = to_binary(data)

              receive do
                :cont ->
                  case SSHKit.Channel.send(chan, chunk) do
                    :ok -> send(owner, {:write, chan, self(), chunk})
                    other -> send(owner, {:error, chan, self(), other})
                  end
              end
              :ok

            :close, ^chan ->
              # IO.puts("close")
              :ok = SSHKit.Channel.eof(chan)
              send(owner, {:close, chan, self()})
              :ok
          end)

          :ok = :erl_tar.add(tar, to_charlist(source), to_charlist(Path.basename(source)), [])
          :ok = :erl_tar.close(tar)

          :ok = SSHKit.Channel.close(chan)
        end)

        tarpipe
      end,
      fn tarpipe ->
        send(tarpipe, :cont)

        receive do
          {:write, chan, ^tarpipe, data} ->
            {[{:write, chan, data}], tarpipe}

          {:close, chan, ^tarpipe} ->
            {:halt, tarpipe}

          {:error, chan, ^tarpipe, error} ->
            IO.inspect(error, label: "received error")
            {:halt, tarpipe}
        end

        # case Tarpipe.proceed(tarpipe) do
        #   {:write, …} -> {[], tarpipe}
        #   {:error, …} -> raise
        # end
      end,
      fn tarpipe ->
        nil # :ok = Tarpipe.close(tarpipe)
      end
    )
  end

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

stream = TP.upload!(conn, "test/fixtures", "upload", context: ctx)

Enum.each(stream, fn
  {:write, chan, data} ->
    IO.puts("Upload, sent #{byte_size(data)} bytes")
end)

:ok = SSHKit.close(conn)
