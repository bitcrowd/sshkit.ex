defmodule SSHKit.FunctionalCaseHelpers do
  @moduledoc false

  def exec!(_host = %{id: id}, command, args \\ []) do
    Docker.exec!([], id, command, args)
  end

  def adduser!(host, username) do
    exec!(host, "adduser", ["-D", username])
  end

  def addgroup!(host, groupname) do
    exec!(host, "addgroup", [groupname])
  end

  def add_user_to_group!(host, username, groupname) do
    exec!(host, "addgroup", [username, groupname])
  end

  def chpasswd!(host, username, password) do
    command = "echo #{username}:#{password} | chpasswd 2>&1"
    exec!(host, "sh", ["-c", command])
  end

  def keygen!(host, username) do
    exec!(host, "sh", [
      "-c",
      "ssh-keygen -b 1024 -f /tmp/#{username} -N '' -C \"#{username}@$(hostname)\""
    ])

    exec!(host, "sh", ["-c", "cat /tmp/#{username}.pub > /home/#{username}/.ssh/authorized_keys"])
  end
end
