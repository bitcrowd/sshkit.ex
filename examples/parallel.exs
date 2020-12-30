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
      conn
      |> SSHKit.exec!("uptime")
      |> Enum.reduce(nil, fn
        {:stdout, chan, output}, status ->
          IO.write("[#{label.(chan.connection)}] (stdout) #{output}")
          status

        {:stderr, chan, output}, status ->
          IO.write("[#{label.(chan.connection)}] (stderr) #{output}")
          status

        {:exit_status, _, status}, _ ->
          status

        _, status ->
          status
      end)
    end)
  end)

tasks
|> Enum.map(&Task.await/1)
|> Enum.filter(&(&1 != 0))
|> Enum.zip(conns)
|> Enum.each(fn {status, conn} ->
  IO.puts("[#{label.(conn)}] exited with status #{status}")
end)

:ok = Enum.each(conns, &SSHKit.close/1)
