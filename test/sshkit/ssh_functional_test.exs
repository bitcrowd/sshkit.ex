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

  @tag boot: 1
  test "opens a connection and runs an SSH command as a lambda function", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    func    = fn(conn) -> SSH.run(conn, "id -un") end
    result  = {:ok, [stdout: "me\n"], 0}

    assert SSH.connect(host.ip, options, func) == {:ok, result}
  end

  test "returns error with nil host" do
    assert {:error, _} = SSH.connect(nil)
  end
end
