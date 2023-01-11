{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

:ok =
  conn
  |> SSHKit.upload!("test/fixtures", "/tmp/fixtures")
  |> Stream.run()

:ok = SSHKit.close(conn)
