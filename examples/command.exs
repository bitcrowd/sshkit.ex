{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

conn
|> SSHKit.run!(~S(uname -a && ssh -V))
|> Enum.each(fn {type, data} -> IO.write("#{type}: #{data}") end)

:ok = SSHKit.close(conn)
