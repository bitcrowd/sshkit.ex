defmodule SSHKit.Context do
  import SSHKit.Utils

  defstruct [hosts: [], env: nil, path: nil, umask: nil, user: nil, group: nil]

  def build(context, command) do
    # cmd(command)
    # |> sudo(context.user, context.group)
    # |> export(context.env)
    # |> umask(context.umask)
    # |> cd(context.path)

    cmd(command)
    |> group(context.group)
    |> user(context.user)
    |> env(context.env)
    |> umask(context.umask)
    |> path(context.path)
  end

  defp cmd(command), do: "/usr/bin/env #{command}"

  defp group(command, nil), do: command
  defp group(command, name), do: command # TODO

  defp user(command, nil), do: command
  defp user(command, name), do: "sudo -u #{name} -- sh -c #{shellquote(command)}"

  defp env(command, nil), do: command
  defp env(command, %{}), do: command
  defp env(command, env) do
    exports = Enum.map_join(env, " ", fn {name, value} -> "#{name}=#{value}" end)
    "(export #{exports} && #{command})"
  end

  defp umask(command, nil), do: command
  defp umask(command, mask), do: "umask #{mask} && #{command}"

  defp path(command, nil), do: command
  defp path(command, path), do: "cd #{path} && #{command}"
end
