defmodule SSHKit.FunctionalAssertionHelpers do
  @moduledoc false
  import ExUnit.Assertions
  alias SSHKit.Context
  alias SSHKit.SSH

  def verify_transfer(conn, local, remote) do
    command = &"find #{&1} -type f -exec #{&2} {} \\; | sort | awk '{print $1}' | xargs"
    compare_command_output(conn,
      command.(local, SystemCommands.shasum_cmd()),
      command.(remote, "sha1sum")
      )
  end

  def verify_mode(conn, local, remote) do
    command = &"find #{&1} -type f -exec ls -l {} + | awk '{print $1 $5}' | sort |xargs"
    compare_command_output(conn,
      command.(local),
      command.(remote)
      )
  end

  def verify_atime(conn, local, remote) do
    command = &"env find #{&1} -type f -exec #{&2} {} \\; | cut -f1,2 | sort | xargs"
      compare_command_output(conn,
        command.(local, SystemCommands.stat_cmd()),
        command.(remote, "stat -c '%s\t%X\t%Y'")
      )
  end

  def verify_mtime(conn, local, remote) do
    command = &"env find #{&1} -type f -exec #{&2} {} \\; | cut -f1,3 | sort | xargs"
    compare_command_output(conn,
      command.(local, SystemCommands.stat_cmd()),
      command.(remote, "stat -c '%s\t%X\t%Y'")
      )
  end

  def compare_command_output(context = %Context{}, local, remote) do
    Enum.map(context.hosts,
      fn(h) ->
        SSH.connect h.name, h.options, fn(conn) ->
          compare_command_output(conn, local, remote)
        end
      end)
  end

  def compare_command_output(conn, local, remote) do
    local_output = local |> String.to_charlist |> :os.cmd |> to_string
    {:ok, [stdout: remote_output], 0} = SSH.run(conn, remote)
    assert local_output == remote_output
  end

  def create_local_tmp_path do
    rand =
      16
      |> :crypto.strong_rand_bytes()
      |> Base.url_encode64()
      |> binary_part(0, 16)

    Path.join(System.tmp_dir(), "sshkit-test-#{rand}")
  end
end
