defmodule SSHKit.SSHFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]

  @tag boot: 1
  test "opens a connection with username and password", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
    {:ok, data, status} = SSH.run(conn, "id -un")

    assert [stdout: "#{host.user}\n"] == data
    assert 0 = status
  end
end
