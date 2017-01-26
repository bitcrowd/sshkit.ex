defmodule SSHKitTest do
  use ExUnit.Case
  # doctest SSHKit

  test "connects" do
  end

  test "command" do
    context =
      SSHKit.context('192.168.99.100')
      |> SSHKit.cd("/var/log")
      |> SSHKit.env("PATH", "$HOME/.rbenv/shims:$PATH")

    IO.inspect(SSHKit.Context.build(context, "ls"))
  end

  @tag :skip
  test "dsl" do
    options = [port: 2222, user: 'test', password: 'test']

    context =
      SSHKit.context({'192.168.99.100', options})
      |> SSHKit.cd("/var/log")
      |> SSHKit.env("PATH", "$HOME/.rbenv/shims:$PATH")

    # IO.inspect(context.hosts)

    [{:ok, output, status}] = SSHKit.run(context, "env")

    assert status == 0

    env =
      output
      |> Keyword.get_values(:normal)
      |> Enum.join("")
      |> String.split("\n")

    assert Enum.any?(env, &(String.starts_with?(&1, "PATH=/home/test/.rbenv/shims:")))

    [{:ok, output, status}] = SSHKit.run(context, "pwd")

    assert status == 0

    dir =
      output
      |> Keyword.get_values(:normal)
      |> Enum.join("")
      |> String.replace(~r{\n$}, "")

    assert dir == "/var/log"

    IO.inspect(SSHKit.cd(context, "..") |> SSHKit.run("pwd"))

    [{:ok, output, status}] = SSHKit.run(context, "whoami")

    assert status == 0

    user =
      output
      |> Keyword.get_values(:normal)
      |> Enum.join("")
      |> String.replace(~r{\n$}, "")

    assert user == "test"
  end
end
