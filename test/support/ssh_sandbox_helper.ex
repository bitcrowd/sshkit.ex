defmodule SSHSandboxHelper do
  @moduledoc false

  def ssh(%{ssh: :error}), do: SSHSandbox.SSH.Error
  def ssh(_), do: SSHSandbox.SSH.Success

  def ssh_connection(%{ssh_connection: :failure}), do: SSHSandbox.SSHConnection.Failure
  def ssh_connection(%{ssh_connection: :timeout}), do: SSHSandbox.SSHConnection.Timeout
  def ssh_connection(%{ssh_connection: :error}), do: :ssh_connection
  def ssh_connection(_), do: SSHSandbox.SSHConnection.Success
end
