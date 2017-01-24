defmodule SSHKit.SSHTest do
  use SSHKit.FunctionalCase

  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]

  test "opens a connection with username and password" do
    host = '192.168.99.100'
    options = [port: 2222, user: 'test', password: 'test']
    command = 'whoami'

    {:ok, conn} = SSH.connect(host, Keyword.merge(@defaults, options))
    {:ok, data, status} = SSH.run(conn, command)

    assert [normal: "test\n"] = data
    assert 0 = status
  end
end
