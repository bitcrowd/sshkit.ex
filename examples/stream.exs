# TODO: Timeouts?
# TODO: Multiple hosts?

{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

{:ok, chan} = SSHKit.run(conn, ~S(echo "Who's there?"; read msg; echo "Hello $msg!"))

{:ok, out1} = SSHKit.stream(chan, "", fn {:stdout, ^chan, data}, buffer ->
  tag = if String.ends_with?(data, "\n"), do: :halt, else: :cont
  {tag, buffer <> data}
end)

out1
|> String.trim()
|> IO.puts()

:ok = SSHKit.send(chan, "SSHKit\n")

{:ok, out2} = SSHKit.stream(chan, "", fn
  {:stdout, ^chan, data}, buffer ->
    {:cont, buffer <> data}

  {:closed, ^chan}, buffer ->
    {:halt, buffer}

  _, buffer ->
    {:cont, buffer}
end)

out2
|> String.trim()
|> IO.puts()

:ok = SSHKit.close(conn)
