{:ok, conn} = SSHKit.connect("127.0.0.1", port: 2222, user: "deploy", password: "deploy", silently_accept_hosts: true)

stream = SSHKit.exec!(conn, ~S(echo "Who's there?"; read name; echo -n "Hello"; sleep 3; echo " $name."))

:ok = IO.write("> ")

code = Enum.reduce(stream, nil, fn
  {:stdout, chan, chunk}, status ->
    :ok = IO.write("#{chunk}")

    if String.ends_with?(chunk, "?\n") do
      :ok = SSHKit.send(chan, "SSHKit\n")
      :ok = IO.write("< SSHKit\n")
      :ok = IO.write("> ")
    end

    status

  {:exit, _, status}, _ ->
    status

  _, status ->
    status
end)

:ok = IO.puts("? #{code}")

:ok = SSHKit.close(conn)
