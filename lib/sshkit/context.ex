defmodule SSHKit.Context do
  import SSHKit.Utils

  # defstruct hosts: [], env: [], pwd: [], umask: nil, user: nil, group: nil
  defstruct [:hosts, :stack]

  @keys [:cd, :umask, :env, :user, :group]

  # def env(context, key, value) do
  #   %{context | stack: [{:env, {key, value}} | context.stack]}
  # end

  # def cd(context, key, value) do
  #   %{context | stack: [{:env, {key, value}} | context.stack]}
  # end

  def push(context, {key, value}) when key in @keys do
    %{context | stack: [{key, value} | context.stack]}
  end

  def build(context, command) do
    one = fn kw, key -> List.wrap(Keyword.get(kw, key)) end
    all = fn kw, key -> Keyword.take(kw, [key]) end

    stack = []

    one.(stack, :group)
    |> Enum.into(one.(stack, :user))
    |> Enum.into(all.(stack, :env))
    |> Enum.into([{:isolate, ~w{( )}}])
    |> Enum.into(one.(stack, :umask))
    |> Enum.into(all.(stack, :cd))
    |> List.foldr("/usr/bin/env #{command}", &mod/2)

    # ~s{cd _ && cd _ && umask 007 (export A=z; export A=x:y:$A; sudo -u USER -- sh -c 'sg GROUP -c \'/usr/bin/env uptime\'')}
  end

  defp mod({:cd, path}, cmd), do: ~s{cd #{path} && #{cmd}}
  defp mod({:user, name}, cmd), do: ~s{sudo -u #{name} -- sh -c '#{cmd}'}
  defp mod({:group, name}, cmd), do: ~s{sg #{name} -c \'#{cmd}\'}
  defp mod({:umask, mask}, cmd), do: ~s{umask #{mask} && #{cmd}}
  defp mod({:isolate, _}, cmd), do: ~s{(#{cmd})}
  defp mod({:env, {name, value}}, cmd), do: ~s{export #{name}=#{shellescape(value)}; #{cmd}}
end
