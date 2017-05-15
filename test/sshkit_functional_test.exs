defmodule SSHKitFunctionalTest do
  @moduledoc false

  import SSHKit.FunctionalCaseHelpers

  use SSHKit.FunctionalCase, async: true

  @defaults [silently_accept_hosts: true, timeout: 5000]

  def options(overrides) do
    Keyword.merge(@defaults, overrides)
  end

  def build_context(host) do
    overrides = [port: host.port, user: host.user, password: host.password]
    SSHKit.context({host.ip, Keyword.merge(@defaults, overrides)})
  end

  defp stdio(output, type) do
    output
    |> Keyword.get_values(type)
    |> Enum.join()
  end

  def stdout(output), do: stdio(output, :stdout)
  def stderr(output), do: stdio(output, :stderr)

  @tag boot: 1
  test "connects", %{hosts: [host]} do
    [{:ok, output, 0}] = SSHKit.run(build_context(host), "id -un")
    name = String.trim(stdout(output))
    assert name == host.user
  end

  @tag boot: 1
  test "runs commands", %{hosts: [host]} do
    context = build_context(host)

    [{:ok, output, status}] = SSHKit.run(context, "pwd")
    assert status == 0, stderr(output)
    assert stdout(output) == "/home/me\n"

    [{:ok, output, status}] = SSHKit.run(context, "ls non-existing")
    assert status == 1
    assert stderr(output) =~ "ls: non-existing: No such file or directory"

    [{:ok, output, status}] = SSHKit.run(context, "does-not-exist")
    assert status == 127
    assert stderr(output) =~ "'does-not-exist': No such file or directory"
  end

  @tag boot: 1
  test "env", %{hosts: [host]} do
    [{:ok, output, status}] =
      host
      |> build_context()
      |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH", "NODE_ENV" => "production"})
      |> SSHKit.run("env")

    assert status == 0, stderr(output)

    output = stdout(output)
    assert output =~ "NODE_ENV=production"
    assert output =~ ~r/PATH=.*\/\.rbenv\/shims:/
  end

  @tag boot: 1
  test "umask", %{hosts: [host]} do
    context =
      host
      |> build_context()
      |> SSHKit.umask("077")

    [{:ok, _, 0}] = SSHKit.run(context, "mkdir my_dir")
    [{:ok, _, 0}] = SSHKit.run(context, "touch my_file")

    [{:ok, output, status}] = SSHKit.run(context, "ls -la")

    assert status == 0, stderr(output)

    output = stdout(output)
    assert output =~ ~r/drwx--S---\s+2\s+me\s+me\s+4096.+my_dir/
    assert output =~ ~r/-rw-------\s+1\s+me\s+me\s+0.+my_file/
  end

  @tag boot: 1
  test "path", %{hosts: [host]} do
    context =
      host
      |> build_context()
      |> SSHKit.path("/var/log")

    [{:ok, output, status}] = SSHKit.run(context, "pwd")

    assert status == 0, stderr(output)
    assert stdout(output) == "/var/log\n"
  end

  @tag boot: 1
  test "user", %{hosts: [host]} do
    add_user_to_group(host, host.user, "passwordless-sudoers")

    adduser(host, "despicable_me")

    context =
      host
      |> build_context()
      |> SSHKit.user("despicable_me")

    [{:ok, output, status}] = SSHKit.run(context, "id -un")

    assert status == 0, stderr(output)
    assert stdout(output) == "despicable_me\n"
  end

  @tag boot: 1
  test "group", %{hosts: [host]} do
    add_user_to_group(host, host.user, "passwordless-sudoers")

    adduser(host, "gru")
    addgroup(host, "villains")
    add_user_to_group(host, "gru", "villains")

    context =
      host
      |> build_context()
      |> SSHKit.user("gru")
      |> SSHKit.group("villains")

    [{:ok, output, status}] = SSHKit.run(context, "id -gn")

    assert status == 0, stderr(output)
    assert stdout(output) == "villains\n"
  end
end
