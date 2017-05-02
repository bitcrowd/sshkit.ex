defmodule SSHKitFunctionalTest do
  use SSHKit.FunctionalCase, async: true
  # doctest SSHKit

  @defaults [silently_accept_hosts: true]

  def options(overrides) do
    Keyword.merge(@defaults, overrides)
  end

  def build_context(host) do
    SSHKit.context({
      host.ip,
      options(port: host.port,
              user: host.user,
              password: host.password,
              timeout: 5000
             )
    })
  end

  @tag boot: 1
  test "connects", %{hosts: [host]} do
    [{:ok, output, 0}] = SSHKit.run(build_context(host), "whoami")

    name =
      output
      |> Keyword.get_values(:normal)
      |> Enum.join()
      |> String.trim()

    assert name == host.user
  end

  @tag boot: 1
  test "run", %{hosts: [host]} do
    context =
      build_context(host)
      |> SSHKit.pwd("/var/log")

    [{:ok, output, status}] = SSHKit.run(context, "pwd")
    assert status == 0
    assert output == [normal: "/var/log\n"]

    [{:ok, output, status}] = SSHKit.run(context, "ls non-existing")
    assert status == 1
    [stderr: stderr] = output
    assert stderr =~ "ls: non-existing: No such file or directory"

    [{:ok, output, status}] = SSHKit.run(context, "does-not-exist")
    assert status == 127
    [stderr: stderr] = output
    assert stderr =~ "'does-not-exist': No such file or directory"
  end

  @tag boot: 1
  test "env", %{hosts: [host]} do
    [{:ok, output, status}] =
      build_context(host)
      |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH"})
      |> SSHKit.env(%{"NODE_ENV" => "production"})
      |> SSHKit.run("env")

    assert status == 0
    [normal: stdout] = output
    assert stdout =~ "NODE_ENV=production"
    assert stdout =~ ~r/PATH=.*\/\.rbenv\/shims:/
  end

  @tag boot: 1
  test "umask", %{hosts: [host]} do
    context = build_context(host)
              |> SSHKit.umask("077")
    SSHKit.run(context, "mkdir my_dir")
    SSHKit.run(context, "touch my_file")
    [{:ok, output, status}] = SSHKit.run(context, "ls -ld my_dir my_file")
    IO.inspect(SSHKit.Context.build(context, "mkdir bla"))

    assert status == 0
    # drwx------ 2 vivek vivek 4096 2011-03-04 02:05 dir1
    # -rw------- 1 vivek vivek    0 2011-03-04 02:05 file
    # drwx--S--- 2 me    me    4096 May  2 21:26 my_dir
    # -rw------- 1 me    me       0 May  2 21:26 my_file
    assert output == [normal: "/var/log\n"]
  end
end
