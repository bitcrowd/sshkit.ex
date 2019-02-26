defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @bootconf [user: "me", password: "pass"]

  describe "upload/4" do
    @tag boot: [@bootconf]
    test "sends a file", %{hosts: [host]} do
      source = "test/fixtures/local.txt"
      target = "file.txt"

      command = SCP.Command.build(:upload, target, [])

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, command, source)
        assert verify_transfer(conn, source, target)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true", %{hosts: [host]} do
      source = "test/fixtures"
      target = "/home/#{host.options[:user]}/destination"

      options = [recursive: true]
      command = SCP.Command.build(:upload, target, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, command, source, options)
        assert verify_transfer(conn, source, target)
      end
    end

    @tag boot: [@bootconf]
    test "preserve: true", %{hosts: [host]} do
      source = "test/fixtures/local.txt"
      target = "file.txt"

      options = [preserve: true]
      command = SCP.Command.build(:upload, target, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, command, source, options)
        assert verify_mode(conn, source, target)
        assert verify_atime(conn, source, target)
        assert verify_mtime(conn, source, target)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true, preserve: true", %{hosts: [host]} do
      source = "test/fixtures/"
      target = "/home/#{host.options[:user]}/destination"

      options = [recursive: true, preserve: true]
      command = SCP.Command.build(:upload, target, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.upload(conn, command, source, options)
        assert verify_mode(conn, source, target)
        assert verify_atime(conn, source, target)
        assert verify_mtime(conn, source, target)
      end
    end
  end

  describe "download/4" do
    @tag boot: [@bootconf]
    test "gets a file", %{hosts: [host]} do
      source = "/fixtures/remote.txt"
      target = create_local_tmp_path()
      on_exit fn -> File.rm(target) end

      command = SCP.Command.build(:download, source, [])

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, command, target)
        assert verify_transfer(conn, target, source)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true", %{hosts: [host]} do
      source = "/fixtures"
      target = create_local_tmp_path()
      on_exit fn -> File.rm_rf(target) end

      options = [recursive: true]
      command = SCP.Command.build(:download, source, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, command, target, options)
        assert verify_transfer(conn, target, source)
      end
    end

    @tag boot: [@bootconf]
    test "preserve: true", %{hosts: [host]} do
      source = "/fixtures/remote.txt"
      target = create_local_tmp_path()
      on_exit fn -> File.rm(target) end

      options = [preserve: true]
      command = SCP.Command.build(:download, source, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, command, target, options)
        assert verify_mode(conn, target, source)
        assert verify_atime(conn, target, source)
        assert verify_mtime(conn, target, source)
      end
    end

    @tag boot: [@bootconf]
    test "recursive: true, preserve: true", %{hosts: [host]} do
      source = "/fixtures"
      target = create_local_tmp_path()
      on_exit fn -> File.rm_rf(target) end

      options = [recursive: true, preserve: true]
      command = SCP.Command.build(:download, source, options)

      SSH.connect host.name, host.options, fn conn ->
        assert :ok = SCP.download(conn, command, target, options)
        assert verify_mode(conn, target, source)
        assert verify_atime(conn, target, source)
        assert verify_mtime(conn, target, source)
      end
    end
  end
end
