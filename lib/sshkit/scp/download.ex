defmodule SSHKit.SCP.Download do
  alias SSHKit.SCP.Command
  # alias SSHKit.SSH.Channel

  @doc """
  Downloads a file or directory from a remote host.

  ## Options

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Example

  ```
  :ok = SSHKit.SCP.Download.transfer(conn, '/home/code/sshkit', 'downloads', recursive: true)
  ```
  """
  def transfer(connection, remote, local, options \\ []) do
    :ok
  end
end
