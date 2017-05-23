defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]
  @local_workspace "test/fixtures/local_workspace"
  @remote_workspace "/workspace"
  @local_remote_workspace "test/fixtures/docker_workspace"

  @tag boot: 1
  test "uploads a file", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    local = "#{@local_workspace}/local_file.txt"
    remote = "#{@remote_workspace}/#{host.id}.file"
    shared = "#{@local_remote_workspace}/#{host.id}.file"

    {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
    assert :ok = SCP.upload(conn, local, remote)
    assert File.read(local) == File.read(shared)
    File.rm!(shared)
  end

  @tag boot: 1
  test "downloads a file", %{hosts: [host]} do
    options = [port: host.port, user: host.user, password: host.password]
    remote = "#{@remote_workspace}/remote_file.txt"
    local = "#{@local_workspace}/#{host.id}.file"
    shared = "#{@local_remote_workspace}/remote_file.txt"

    {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))
    assert :ok = SCP.download(conn, remote, local)
    assert File.read(shared) == File.read(local)
    File.rm!(local)
  end
end
