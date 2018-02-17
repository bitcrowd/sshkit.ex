defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @bootconf [user: "me", password: "pass"]

  describe "upload/4" do
    @tag boot: [@bootconf]
    test "sends a file", %{hosts: [host]} do
      local = "test/fixtures/local.txt"
      remote = "file.txt"

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, local, remote)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true", %{hosts: [host]} do
      local = "test/fixtures"
      remote = "/home/#{host.options[:user]}/destination"

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, local, remote, recursive: true)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "preserve: true", %{hosts: [host]} do
      local = "test/fixtures/local.txt"
      remote = "file.txt"

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, local, remote, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true, preserve: true", %{hosts: [host]} do
      local = "test/fixtures/"
      remote = "/home/#{host.options[:user]}/destination"

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, local, remote, recursive: true, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end
  end

  describe "download/4" do
    @tag boot: [@bootconf]
    test "gets a file", %{hosts: [host]} do
      remote = "/fixtures/remote.txt"
      local = create_local_tmp_path()
      on_exit fn -> File.rm(local) end

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, remote, local)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true", %{hosts: [host]} do
      remote = "/fixtures"
      local = create_local_tmp_path()
      on_exit fn -> File.rm_rf(local) end

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, remote, local, recursive: true)
        assert verify_transfer(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "preserve: true", %{hosts: [host]} do
      remote = "/fixtures/remote.txt"
      local = create_local_tmp_path()
      on_exit fn -> File.rm(local) end

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, remote, local, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_atime(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true, preserve: true", %{hosts: [host]} do
      remote = "/fixtures"
      local = create_local_tmp_path()
      on_exit fn -> File.rm_rf(local) end

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, remote, local, recursive: true, preserve: true)
        assert verify_mode(conn, local, remote)
        assert verify_atime(conn, local, remote)
        assert verify_mtime(conn, local, remote)
      end
    end
  end
end
