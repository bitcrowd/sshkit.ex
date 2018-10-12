defmodule SSHKit.SCP do
  @moduledoc ~S"""
  Provides convenience functions for transferring files or directory trees to
  or from a remote host via SCP.

  Built on top of `SSHKit.SSH`.

  ## Common options

  These options are available for both uploads and downloads:

  * `:verbose` - let the remote scp process be verbose, default `false`
  * `:recursive` - set to `true` for copying directories, default `false`
  * `:preserve` - preserve timestamps, default `false`
  * `:timeout` - timeout in milliseconds, default `:infinity`

  ## Examples

  ```
  {:ok, conn} = SSHKit.SSH.connect("eg.io", user: "me")
  :ok = SSHKit.SCP.upload(conn, ".", "/home/code/phx", recursive: true)
  :ok = SSHKit.SSH.close(conn)
  ```
  """

  alias SSHKit.SCP.Download
  alias SSHKit.SCP.Upload

  @doc """
  Uploads a local file or directory to a remote host.

  ## Options

  See `SSHKit.SCP.Upload.transfer/4`.

  ## Example

  ```
  :ok = SSHKit.SCP.upload(conn, ".", "/home/code/sshkit", recursive: true)
  ```
  """
  def upload(connection, local, remote, options \\ []) do
    Upload.transfer(connection, local, remote, options)
  end

  @doc """
  Downloads a file or directory from a remote host.

  ## Options

  See `SSHKit.SCP.Download.transfer/4`.

  ## Example

  ```
  :ok = SSHKit.SCP.download(conn, "/home/code/sshkit", "downloads", recursive: true)
  ```
  """
  def download(connection, remote, local, options \\ []) do
    Download.transfer(connection, remote, local, options)
  end
end
