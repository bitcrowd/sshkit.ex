defmodule SSHKit.Context do
  @moduledoc """
  Holds information about the context in which a command can be executed.
  This includeds the `group`, `user`, `umask` setting, `path`,
  environment variables, as well as the hosts a command should be on.

  `build/2` compiles a context into an executable command string.
  """

  import SSHKit.Utils

  defstruct [hosts: [], env: nil, path: nil, umask: nil, user: nil, group: nil]

  @doc """
  Compile the given context into a string that is executable (via SSH) on a shell.

  ## Parameters

  * `context`: a `SSHKit.Context` struct
  * `command`: a string containing the command to execute in that context
  """
  def build(context, command) do
    command
    |> cmd
    |> group(context.group)
    |> user(context.user)
    |> env(context.env)
    |> umask(context.umask)
    |> path(context.path)
  end

  defp cmd(command), do: "/usr/bin/env #{command}"

  defp group(command, nil), do: command
  defp group(command, _name), do: command

  defp user(command, nil), do: command
  defp user(command, name), do: "sudo -u #{name} -- sh -c #{shellquote(command)}"

  defp env(command, nil), do: command
  defp env(command, env) do
    exports = Enum.map_join(env, " ", fn {name, value} -> "#{name}=\"#{value}\"" end)
    "(export #{exports} && #{command})"
  end

  defp umask(command, nil), do: command
  defp umask(command, mask), do: "umask #{mask} && #{command}"

  defp path(command, nil), do: command
  defp path(command, path), do: "cd #{path} && #{command}"
end
