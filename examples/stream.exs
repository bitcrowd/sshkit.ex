{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

{:ok, chan} = SSHKit.run(conn, ~S(echo "Who's there?"; read name; echo "Hello $name"))

IO.write("> ")

chan
|> SSHKit.stream()
|> Stream.map(fn {:stdout, ^chan, chunk} -> chunk end)
|> Stream.each(&IO.write/1)
|> Stream.take_while(fn chunk -> !String.ends_with?(chunk, "\n") end)
|> Stream.run()

IO.write("< SSHKit\n")

:ok = SSHKit.send(chan, "SSHKit\n")

IO.write("> ")

# TODO: Timeouts?
chan
|> SSHKit.stream()
|> Stream.filter(fn msg -> elem(msg, 0) == :stdout end)
|> Stream.map(fn {:stdout, ^chan, chunk} -> chunk end)
|> Stream.each(&IO.write/1)
|> Stream.run()

:ok = SSHKit.close(conn)
