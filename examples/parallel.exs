defaults = [user: "deploy", password: "deploy", silently_accept_hosts: true]

hosts =
  [{"127.0.0.1", port: 2222}, {"127.0.0.1", port: 2223}]
  |> Enum.map(fn {name, options} -> {name, Keyword.merge(defaults, options)} end)

conns = Enum.map(hosts, fn {name, options} ->
  {:ok, conn} = SSHKit.connect(name, options)
  conn
end)

label = fn conn -> Enum.join([conn.host, conn.port], ":") end

tasks =
  Enum.map(conns, fn conn ->
    Task.async(fn ->
      {:ok, chan} = SSHKit.exec(conn, "uptime")

      chan
      |> SSHKit.stream!()
      |> Enum.reduce(nil, fn
        {:stdout, chan, output}, acc ->
          IO.write("[#{label.(chan.connection)}] (stdout) #{output}")
          acc

        {:stderr, chan, output}, acc ->
          IO.write("[#{label.(chan.connection)}] (stderr) #{output}")
          acc

        {:exit, _, status}, _ ->
          status

        _, acc ->
          acc
      end)
    end)
  end)

okay? = fn status -> status == 0 end

results = Enum.map(tasks, &Task.await/1)

unless Enum.all?(results, okay?) do
  results
  |> Enum.with_index()
  |> Enum.filter(fn {status, _} -> !okay?.(status) end)
  |> Enum.each(fn {status, index} ->
    conn = Enum.at(conns, index)
    IO.puts("[#{label.(conn)}] exited with status #{status}")
  end)
end

:ok = Enum.each(conns, &SSHKit.close/1)
