defmodule SSHKit.FunctionalCase do
  use ExUnit.CaseTemplate

  setup tags do
    # IO.inspect(Map.get(tags, :servers, 1))

    cmd = "/usr/sbin/sshd"
    args = ["-D"]

    # For debugging, let sshd be more verbose:
    # args = ["-D", "-d", "-d", "-d"]

    id = Docker.run!(["--rm", "--detach", "--publish-all"], "sshkit-test-sshd", cmd, args)

    # set up container(s) with user(s) & key(s)
    addr = Docker.cmd!("port", [id, "22/tcp"])
    uri = URI.parse("tcp://" <> addr)

    IO.puts(id)
    IO.puts(uri.port)
    IO.puts(Docker.exec!(id, "whoami"))

    on_exit fn ->
      Docker.kill!([id])
      :ok
    end

    # expose host objects with port, user, key information

    :ok
  end
end
