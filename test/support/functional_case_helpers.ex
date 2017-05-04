defmodule SSHKit.FunctionalCaseHelpers do
  @moduledoc false

  def adduser(_host = %{id: id}, username) do
    Docker.exec!([], id, "adduser", ["-D", username])
  end

  def addgroup(_host = %{id: id}, groupname) do
    Docker.exec!([], id, "addgroup", [groupname])
  end

  def add_user_to_group(_host = %{id: id}, username, groupname) do
    Docker.exec!([], id, "addgroup", [username, groupname])
  end

  def chpasswd(_host = %{id: id}, username, password) do
    command = "echo #{username}:#{password} | chpasswd 2>&1"
    Docker.exec!([], id, "sh", ["-c", command])
  end

  def keygen(_host = %{id: id}, username) do
    Docker.exec!([], id, "sh", ["-c", "ssh-keygen -b 1024 -f /tmp/#{username} -N '' -C \"#{username}@$(hostname)\""])
    Docker.exec!([], id, "sh", ["-c", "cat /tmp/#{username}.pub > /home/#{username}/.ssh/authorized_keys"])
  end
end
