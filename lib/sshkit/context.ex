defmodule SSHKit.Context do
  @moduledoc """
  Holds information about the context in which a command can be executed.
  This includes the `group`, `user`, `umask` setting, working directory,
  environment variables, as well as the hosts a command should run on.

  `build/2` compiles a context into an executable command string.
  """

  import SSHKit.Utils

  defstruct [hosts: [], env: nil, path: nil, umask: nil, user: nil, group: nil]

  @doc """
  Compiles an executable command string for running the given `command` in the provided `context`.

  ## Example

  ```
  iex> %SSHKit.Context{path: "/var/www"} |> SSHKit.Context.build("ls")
  "cd /var/www && /usr/bin/env ls"
  ```
  """
  def build(context, command) do
    "/usr/bin/env #{command}"
    |> sudo(context.user, context.group)
    |> export(context.env)
    |> umask(context.umask)
    |> cd(context.path)
  end

  defp sudo(command, nil, nil), do: command
  defp sudo(command, username, nil), do: "sudo -n -u #{username} -- sh -c #{shellquote(command)}"
  defp sudo(command, nil, groupname), do: "sudo -n -g #{groupname} -- sh -c #{shellquote(command)}"
  defp sudo(command, username, groupname), do: "sudo -n -u #{username} -g #{groupname} -- sh -c #{shellquote(command)}"

  defp export(command, nil), do: command
  defp export(command, env) do
    exports = Enum.map_join(env, " ", fn {name, value} -> "#{name}=\"#{value}\"" end)
    "(export #{exports} && #{command})"
  end

  defp umask(command, nil), do: command
  defp umask(command, mask), do: "umask #{mask} && #{command}"

  defp cd(command, nil), do: command
  defp cd(command, path), do: "cd #{path} && #{command}"
end
