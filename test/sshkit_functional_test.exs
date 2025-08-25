defmodule SSHKitFunctionalTest do
  @moduledoc false

  use SSHKit.FunctionalCase, async: true

  @bootconf [user: "me", password: "pass"]

  describe "run/2" do
    @tag boot: [@bootconf]
    test "connects as the login user and runs commands", %{hosts: [host]} do
      [{:ok, output, 0}] =
        host
        |> SSHKit.context()
        |> SSHKit.run("id -un")

      name = String.trim(stdout(output))
      assert name == host.options[:user]
    end

    @tag boot: [@bootconf]
    test "connects as the login user and runs commands in parallel", %{hosts: [host]} do
      begin_time = Time.utc_now()
      [{:ok, output1, 0},{:ok, output2, 0}] =
        [host, host]
        |> SSHKit.context()
        |> SSHKit.run("sleep 2; id -un", :parallel)
      end_time = Time.utc_now()
      run_time = Time.diff(end_time, begin_time, :second)

      assert run_time < 4
      assert String.trim(stdout(output1)) == host.options[:user]
      assert String.trim(stdout(output2)) == host.options[:user]

    end
    
    @tag boot: [@bootconf]
    test "runs commands and returns their output and exit status", %{hosts: [host]} do
      context = SSHKit.context(host)

      [{:ok, output, status}] = SSHKit.run(context, "pwd")
      assert status == 0
      assert stdout(output) == "/home/me\n"

      [{:ok, output, status}] = SSHKit.run(context, "ls nonexistent")
      assert status == 1
      assert stderr(output) =~ "ls: nonexistent: No such file or directory"

      [{:ok, output, status}] = SSHKit.run(context, "nonexistent")
      assert status == 127
      assert stderr(output) =~ "'nonexistent': No such file or directory"
    end

    @tag boot: [@bootconf]
    test "with env", %{hosts: [host]} do
      [{:ok, output, status}] =
        host
        |> SSHKit.context()
        |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH", "NODE_ENV" => "production"})
        |> SSHKit.run("env")

      assert status == 0

      output = stdout(output)
      assert output =~ ~r/^NODE_ENV=production$/m
      assert output =~ ~r/^PATH=\/home\/me\/.rbenv\/shims:.*$/m
    end

    @tag boot: [@bootconf]
    test "with umask", %{hosts: [host]} do
      context =
        host
        |> SSHKit.context()
        |> SSHKit.umask("077")

      [{:ok, _, 0}] = SSHKit.run(context, "mkdir my_dir")
      [{:ok, _, 0}] = SSHKit.run(context, "touch my_file")

      [{:ok, output, status}] = SSHKit.run(context, "ls -la")

      assert status == 0

      output = stdout(output)
      assert output =~ ~r/^drwx--S---\s+2\s+me\s+me\s+4096.+\smy_dir$/m
      assert output =~ ~r/^-rw-------\s+1\s+me\s+me\s+0.+\smy_file$/m
    end

    @tag boot: [@bootconf]
    test "with path", %{hosts: [host]} do
      context =
        host
        |> SSHKit.context()
        |> SSHKit.path("/var/log")

      [{:ok, output, status}] = SSHKit.run(context, "pwd")

      assert status == 0
      assert stdout(output) == "/var/log\n"
    end

    @tag boot: [@bootconf]
    test "with user", %{hosts: [host]} do
      add_user_to_group!(host, host.options[:user], "passwordless-sudoers")
      adduser!(host, "despicable_me")

      context =
        host
        |> SSHKit.context()
        |> SSHKit.user("despicable_me")

      [{:ok, output, status}] = SSHKit.run(context, "id -un")

      assert status == 0
      assert stdout(output) == "despicable_me\n"
    end

    @tag boot: [@bootconf]
    test "with group", %{hosts: [host]} do
      add_user_to_group!(host, host.options[:user], "passwordless-sudoers")

      adduser!(host, "gru")
      addgroup!(host, "villains")
      add_user_to_group!(host, "gru", "villains")

      context =
        host
        |> SSHKit.context()
        |> SSHKit.user("gru")
        |> SSHKit.group("villains")

      [{:ok, output, status}] = SSHKit.run(context, "id -gn")

      assert status == 0
      assert stdout(output) == "villains\n"
    end

    @tag boot: [@bootconf]
    test "with path, umask, user, group and env", %{hosts: [host]} do
      add_user_to_group!(host, host.options[:user], "passwordless-sudoers")

      adduser!(host, "stuart")
      addgroup!(host, "minions")
      add_user_to_group!(host, "stuart", "minions")

      context =
        host
        |> SSHKit.context()
        |> SSHKit.path("/tmp")
        |> SSHKit.user("stuart")
        |> SSHKit.group("minions")
        |> SSHKit.umask("077")
        |> SSHKit.env(%{"INSTRUMENT" => "super-mega ukulele"})

      [{:ok, output, status}] = SSHKit.run(context, "echo $INSTRUMENT > bag")

      assert status == 0
      assert output == []

      info = exec!(host, "ls", ["-l", "/tmp/bag"])
      assert info =~ ~r/^-rw-------\s+1\s+stuart\s+minions\s+.+\s+\/tmp\/bag$/m

      content = exec!(host, "cat", ["/tmp/bag"])
      assert content == "super-mega ukulele"
    end
  end

  describe "upload/3" do
    @describetag boot: [@bootconf, @bootconf]

    test "uploads a file", %{hosts: hosts} do
      local = "test/fixtures/local.txt"

      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.upload(context, local)
      assert verify_transfer(context, local, Path.basename(local))
    end

    test "uploads a file to a directory that does not exist", %{hosts: hosts} do
      local = "test/fixtures/local.txt"

      context =
        hosts
        |> SSHKit.context()
        |> SSHKit.path("/otp/releases")

      assert [
               error: "sh: cd: line 1: can't cd to /otp/releases",
               error: "sh: cd: line 1: can't cd to /otp/releases"
             ] = SSHKit.upload(context, local)
    end

    test "uploads a file to a directory we have no access to", %{hosts: hosts} do
      local = "test/fixtures/local.txt"

      context =
        hosts
        |> SSHKit.context()
        |> SSHKit.path("/")

      assert [
               error: "SCP exited with non-zero exit code 1: scp: local.txt: Permission denied",
               error: "SCP exited with non-zero exit code 1: scp: local.txt: Permission denied"
             ] = SSHKit.upload(context, local)
    end

    test "recursive: true", %{hosts: [host | _] = hosts} do
      local = "test/fixtures"
      remote = "/home/#{host.options[:user]}/fixtures"

      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.upload(context, local, recursive: true)
      assert verify_transfer(context, local, remote)
    end

    test "preserve: true", %{hosts: hosts} do
      local = "test/fixtures/local.txt"
      remote = Path.basename(local)

      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.upload(context, local, preserve: true)
      assert verify_transfer(context, local, remote)
      assert verify_mode(context, local, remote)
      assert verify_mtime(context, local, remote)
    end

    test "recursive: true, preserve: true", %{hosts: [host | _] = hosts} do
      local = "test/fixtures"
      remote = "/home/#{host.options[:user]}/fixtures"

      context = SSHKit.context(hosts)

      assert [:ok, :ok] = SSHKit.upload(context, local, recursive: true, preserve: true)
      assert verify_transfer(context, local, remote)
      assert verify_mode(context, local, remote)
      assert verify_mtime(context, local, remote)
    end

    test "with context", %{hosts: hosts} do
      local = "test/fixtures"
      # path relative to context path
      remote = "target"

      context =
        hosts
        |> SSHKit.context()
        |> SSHKit.path("/tmp")

      assert [:ok, :ok] =
               SSHKit.upload(context, local, recursive: true, preserve: true, as: remote)

      assert verify_transfer(context, local, Path.join(context.path, remote))
      assert verify_mode(context, local, Path.join(context.path, remote))
      assert verify_mtime(context, local, Path.join(context.path, remote))
    end
  end

  describe "download/3" do
    @describetag boot: [@bootconf]

    setup do
      tmpdir = create_local_tmp_path()

      :ok = File.mkdir!(tmpdir)
      on_exit(fn -> File.rm_rf(tmpdir) end)

      {:ok, tmpdir: tmpdir}
    end

    test "gets a file", %{hosts: hosts, tmpdir: tmpdir} do
      remote = "/fixtures/remote.txt"
      local = Path.join(tmpdir, Path.basename(remote))

      context = SSHKit.context(hosts)

      assert [:ok] = SSHKit.download(context, remote, as: local)
      assert verify_transfer(context, local, remote)
    end

    test "recursive: true", %{hosts: hosts, tmpdir: tmpdir} do
      remote = "/fixtures"
      local = Path.join(tmpdir, "fixtures")

      context = SSHKit.context(hosts)

      assert [:ok] = SSHKit.download(context, remote, recursive: true, as: local)
      assert verify_transfer(context, local, remote)
    end

    test "preserve: true", %{hosts: hosts, tmpdir: tmpdir} do
      remote = "/fixtures/remote.txt"
      local = Path.join(tmpdir, Path.basename(remote))

      context = SSHKit.context(hosts)

      assert [:ok] = SSHKit.download(context, remote, preserve: true, as: local)
      assert verify_mode(context, local, remote)
      assert verify_atime(context, local, remote)
      assert verify_mtime(context, local, remote)
    end

    test "recursive: true, preserve: true", %{hosts: hosts, tmpdir: tmpdir} do
      remote = "/fixtures"
      local = Path.join(tmpdir, "fixtures")

      context = SSHKit.context(hosts)

      assert [:ok] = SSHKit.download(context, remote, recursive: true, preserve: true, as: local)
      assert verify_mode(context, local, remote)
      assert verify_atime(context, local, remote)
      assert verify_mtime(context, local, remote)
    end

    test "with context", %{hosts: hosts, tmpdir: tmpdir} do
      # path relative to context path
      remote = "fixtures"
      local = Path.join(tmpdir, "fixtures")

      context =
        hosts
        |> SSHKit.context()
        |> SSHKit.path("/")

      assert [:ok] = SSHKit.download(context, remote, recursive: true, preserve: true, as: local)
      assert verify_transfer(context, local, Path.join(context.path, remote))
      assert verify_mode(context, local, Path.join(context.path, remote))
      assert verify_mtime(context, local, Path.join(context.path, remote))
    end
  end

  defp stdio(output, type) do
    output
    |> Keyword.get_values(type)
    |> Enum.join()
  end

  def stdout(output), do: stdio(output, :stdout)
  def stderr(output), do: stdio(output, :stderr)
end
