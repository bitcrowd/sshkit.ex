defmodule SSHKit.SSHFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SSH

  @bootconf [user: "me", password: "pass"]

  @tag boot: [@bootconf]
  test "opens a connection with username and password, runs a command", %{hosts: [host]} do
    {:ok, conn} = SSH.connect(host.name, host.options)
    {:ok, data, status} = SSH.run(conn, "id -un")
    assert [stdout: "#{host.options[:user]}\n"] == data
    assert 0 = status
  end

  @tag boot: [@bootconf]
  test "opens a connection and runs a command in a lambda function", %{hosts: [host]} do
    fun = fn conn -> SSH.run(conn, "id -un") end
    result = {:ok, [stdout: "#{host.options[:user]}\n"], 0}
    assert SSH.connect(host.name, host.options, fun) == {:ok, result}
  end
end
