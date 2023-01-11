{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

context =
  SSHKit.Context.new()
  |> SSHKit.Context.path("/tmp")
  |> SSHKit.Context.umask("007")
  |> SSHKit.Context.env(%{"X" => "Y"})

conn
|> SSHKit.run!(~S(echo $X && pwd && umask && id -un && id -gn), context: context)
|> Enum.each(fn {type, data} -> IO.write("#{type}: #{data}") end)

:ok = SSHKit.close(conn)
