defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]

  describe "upload/4" do
    @tag boot: 1
    test "sends a file", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local.txt"
      remote = "file.txt"

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.upload(conn, local, remote)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: 1
    test "recursive: true", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures"
      remote = "/home/#{host.user}/destination"

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.upload(conn, local, remote, recursive: true)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: 1
    test "preserve: true", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local.txt"
      remote = "file.txt"

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.upload(conn, local, remote, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end

    @tag boot: 1
    test "recursive: true, preserve: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/"
      remote = "/home/#{host.user}/destination"

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.upload(conn, local, remote, recursive: true, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end
  end

  describe "download/4" do
    @tag boot: 1
    test "gets a file", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures/remote.txt"
      local = create_local_tmp_path()
      on_exit fn -> File.rm(local) end

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.download(conn, remote, local)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: 1
    test "recursive: true", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures"
      local = create_local_tmp_path()
      on_exit fn -> File.rm_rf(local) end

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.download(conn, remote, local, recursive: true)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: 1
    test "preserve: true", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures/remote.txt"
      local = create_local_tmp_path()
      on_exit fn -> File.rm(local) end

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.download(conn, remote, local, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_atime(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end

    @tag boot: 1
    test "recursive: true, preserve: true", %{hosts: [host]} do
      options = @defaults ++ [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures"
      local = create_local_tmp_path()
      on_exit fn -> File.rm_rf(local) end

      SSH.connect host.ip, options, fn(conn) ->
        assert :ok = SCP.download(conn, remote, local, recursive: true, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_atime(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end
  end
end
