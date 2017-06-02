defmodule SSHKit.SCPFunctionalTest do
  use SSHKit.FunctionalCase, async: true

  alias SSHKit.SCP
  alias SSHKit.SSH

  @defaults [silently_accept_hosts: true]

  describe "upload/4" do
    @tag boot: 1
    test "sends a file", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local_workspace/local_file.txt"
      remote = "file.txt"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.upload(conn, local, remote)
      assert verify_transfer(conn, local, remote)
    end

    @tag boot: 1
    test "recursive: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local_workspace"
      remote = "/home/#{host.user}/destination"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.upload(conn, local, remote, recursive: true)
      assert verify_transfer(conn, local, remote)
    end

    @tag boot: 1
    test "preserve: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local_workspace/local_file.txt"
      remote = "file.txt"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.upload(conn, local, remote, preserve: true)
      assert verify_mode(conn, local, remote)
      # assert verify_atime(conn, local, remote)
      assert verify_mtime(conn, local, remote)
    end

    @tag boot: 1
    test "recursive: true, preserve: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      local = "test/fixtures/local_workspace/"
      remote = "/home/#{host.user}/destination"

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.upload(conn, local, remote, recursive: true, preserve: true)
      assert verify_mode(conn, local, remote)
      # assert verify_atime(conn, local, remote)
      assert verify_mtime(conn, local, remote)
    end
  end

  describe "download/4" do
    @tag boot: 1
    test "gets a file", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures/file.txt"
      local = create_random_path()
      on_exit fn -> File.rm(local) end

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.download(conn, remote, local)
      assert verify_transfer(conn, local, remote)
    end

    @tag boot: 1
    test "recursive: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures"
      local = create_random_path()
      on_exit fn -> File.rm_rf(local) end

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.download(conn, remote, local, recursive: true)
      assert verify_transfer(conn, local, remote)
    end

    @tag boot: 1
    test "preserve: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures/file.txt"
      local = create_random_path()
      on_exit fn -> File.rm(local) end

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.download(conn, remote, local, preserve: true)
      assert verify_mode(conn, local, remote)
      # assert verify_atime(conn, local, remote)
      assert verify_mtime(conn, local, remote)
    end

    @tag boot: 1
    test "recursive: true, preserve: true", %{hosts: [host]} do
      options = [port: host.port, user: host.user, password: host.password]
      remote = "/fixtures"
      local = create_random_path()
      on_exit fn -> File.rm_rf(local) end

      {:ok, conn} = SSH.connect(host.ip, Keyword.merge(@defaults, options))

      assert :ok = SCP.download(conn, remote, local, recursive: true, preserve: true)
      assert verify_mode(conn, local, remote)
      # assert verify_atime(conn, local, remote)
      assert verify_mtime(conn, local, remote)
    end
  end

  defp verify_transfer(conn, local, remote) do
    command = "find <%= path %> -type f -exec shasum -a 1 {} \\; | sort | awk '{print $1}' | xargs"
    compare_command_output(conn,
      EEx.eval_string(command, [path: local]),
      EEx.eval_string(command, [path: remote])
      )
  end

  defp verify_mode(conn, local, remote) do
    command = "find <%= path %> -type f -exec perl -e 'print join(\"\",+(stat $ARGV[0])[2,7]),\"\\n\"' {} \\; | sort | xargs"
    compare_command_output(conn,
      EEx.eval_string(command, [path: local]),
      EEx.eval_string(command, [path: remote])
      )
  end

  defp verify_atime(conn, local, remote) do
    command = "find <%= path %> -type f -exec <%= stat %> {} \\; | cut -f1,2 | sort | xargs"
    compare_command_output(conn,
      EEx.eval_string(command, [path: local, stat: get_local_stat_cmd()]),
      EEx.eval_string(command, [path: remote, stat: "stat -c '%s\t%X\t%Y'"])
      )
  end

  defp verify_mtime(conn, local, remote) do
    command = "find <%= path %> -type f -exec <%= stat %> {} \\; | cut -f1,3 | sort | xargs"
    compare_command_output(conn,
      EEx.eval_string(command, [path: local, stat: get_local_stat_cmd()]),
      EEx.eval_string(command, [path: remote, stat: "stat -c '%s\t%X\t%Y'"])
      )
  end

  defp compare_command_output(conn, local, remote) do
    local_output = local |> String.to_char_list |> :os.cmd |>  to_string
    {:ok, [stdout: remote_output], 0} = SSH.run(conn, remote)
    assert local_output == remote_output

  end

  defp get_local_stat_cmd do
    case :os.type() do
      {:unix, :darwin} -> "stat -f '%z\t%a\t%m'"
      _ -> "stat -c '%s\t%X\t%Y'"
    end
  end

  defp create_random_path do
    "/tmp/test_#{16 |> :crypto.strong_rand_bytes |> Base.url_encode64 |> binary_part(0, 16)}"
  end

end
