defmodule SSHKit do
  @moduledoc """
  A toolkit for performing tasks on one or more servers.

  ```
  hosts = ["1.eg.io", {"2.eg.io", port: 2222}]
  hosts = [%SSHKit.Host{name: "3.eg.io", options: [port: 2223]} | hosts]

  context =
    SSHKit.context(hosts)
    |> SSHKit.cd("/var/www/phx")
    |> SSHKit.user("deploy")
    |> SSHKit.group("deploy")
    |> SSHKit.umask("007")
    |> SSHKit.env("NODE_ENV", "production")

  context |> SSHKit.upload(".", recursive: true)
  context |> SSHKit.run("yarn install", mode: :parallel)
  ```
  """

  alias SSHKit.SCP
  alias SSHKit.SSH

  alias SSHKit.Context
  alias SSHKit.Host

  def context(hosts) do
    hosts = List.wrap(hosts) |> Enum.map(&host/1)
    %Context{hosts: hosts, stack: []}
  end

  def host(%{name: name, options: options}) do
    %Host{name: name, options: options}
  end

  def host({name, options}) do
    %Host{name: name, options: options}
  end

  def host(name, options \\ []) do
    %Host{name: name, options: options}
  end

  def cd(context, path) do
    Context.push(context, {:cd, path})
  end

  def user(context, name) do
    Context.push(context, {:user, name})
  end

  def group(context, name) do
    Context.push(context, {:group, name})
  end

  def umask(context, mask) do
    Context.push(context, {:umask, mask})
  end

  def env(context, name, value) do
    Context.push(context, {:env, {name, value}})
  end

  def run(context, command) do
    # TODO: Connection pool, parallel/sequential/grouped runs

    cmd = Context.build(context, command)

    run = fn host ->
      {:ok, conn} = SSH.connect(host.name, host.options)
      SSH.run(conn, cmd)
    end

    Enum.map(context.hosts, run)
  end

  # TODO: SCP operations

  # def upload(context, path, options \\ []) do
  #   …
  #   # resolve remote relative to context path
  #   remote = Path.expand(Map.get(options, :as, Path.basename(path)), _)
  #   SCP.upload(conn, path, remote, options)
  # end

  # def download(context, path, options \\ []) do
  #   …
  #   remote = _ # resolve remote relative to context path
  #   local = Map.get(options, :as, Path.basename(path))
  #   SCP.download(conn, remote, local, options)
  # end
end
