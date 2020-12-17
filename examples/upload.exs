{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

:ok = SSHKit.upload(conn, "test/fixtures", "/tmp/fixtures", recursive: true)

:ok = SSHKit.close(conn)
