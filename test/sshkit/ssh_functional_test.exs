defmodule SSHKit.SSHFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]

  @tag boot: 1
  test "opens a connection with username and password", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
    {:ok, data, status, uuid} = SSH.run(conn, "whoami")

    assert [stdout: "#{host.user}\n"] == data
    assert 0 = status
    assert nil == uuid
  end

  @tag boot: 1
  test "allows passing uuid as option", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
    {:ok, _data, _status, uuid} = SSH.run(conn, "whoami", uuid: "DEADBEEF")

    assert "DEADBEEF" == uuid
  end
end
