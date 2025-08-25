defmodule SSHKit do
  @moduledoc """
  A toolkit for performing tasks on one or more servers.

  ```
  hosts = ["1.eg.io", {"2.eg.io", port: 2222}]

  context =
    SSHKit.context(hosts)
    |> SSHKit.path("/var/www/phx")
    |> SSHKit.user("deploy")
    |> SSHKit.group("deploy")
    |> SSHKit.umask("022")
    |> SSHKit.env(%{"NODE_ENV" => "production"})

  [:ok, :ok] = SSHKit.upload(context, ".", recursive: true)
  [{:ok, _, 0}, {:ok, _, 0}] = SSHKit.run(context, "yarn install", mode: :parallel)
  ```
  """

  alias SSHKit.SCP
  alias SSHKit.SSH

  alias SSHKit.Context
  alias SSHKit.Host

  @doc """
  Produces an `SSHKit.Host` struct holding the information
  needed to connect to a (remote) host.

  ## Examples

  You can pass a map with hostname and options:

  ```
  host = SSHKit.host(%{name: "name.io", options: [port: 2222]})

  # This means, that if you pass in a host struct,
  # you'll get the same result. In particular:
  host == SSHKit.host(host)
  ```

  …or, alternatively, a tuple with hostname and options:

  ```
  host = SSHKit.host({"name.io", port: 2222})
  ```

  See `host/2` for additional details and examples.
  """
  def host(%{name: name, options: options}) do
    %Host{name: name, options: options}
  end

  def host({name, options}) do
    %Host{name: name, options: options}
  end

  @doc """
  Produces an `SSHKit.Host` struct holding the information
  needed to connect to a (remote) host.

  ## Examples

  In its most basic version, you just pass a hostname and all other options
  will use the defaults:

  ```
  host = SSHKit.host("name.io")
  ```

  If you wish to provide additional host options, e.g. a non-standard port,
  you can pass a keyword list as the second argument:

  ```
  host = SSHKit.host("name.io", port: 2222)
  ```

  One or many of these hosts can then be used to create an execution context
  in which commands can be executed:

  ```
  host
  |> SSHKit.context()
  |> SSHKit.run("echo \"That was fun\"")
  ```

  See `host/1` for additional ways of specifying host details.
  """
  def host(host, options \\ [])

  def host(name, options) when is_binary(name) do
    %Host{name: name, options: options}
  end

  def host(%{name: name, options: options}, defaults) do
    %Host{name: name, options: Keyword.merge(defaults, options)}
  end

  def host({name, options}, defaults) do
    %Host{name: name, options: Keyword.merge(defaults, options)}
  end

  @doc """
  Takes one or more (remote) hosts and creates an execution context in which
  remote commands can be run. Accepts any form of host specification also
  accepted by `host/1` and `host/2`, i.e. binaries, maps and 2-tuples.

  See `path/2`, `user/2`, `group/2`, `umask/2`, and `env/2`
  for details on how to derive variations of a context.

  ## Example

  Create an execution context for two hosts. Commands issued in this context
  will be executed on both hosts.

  ```
  hosts = ["10.0.0.1", "10.0.0.2"]
  context = SSHKit.context(hosts)
  ```

  Create a context for hosts with different connection options:

  ```
  hosts = [{"10.0.0.3", port: 2223}, %{name: "10.0.0.4", options: [port: 2224]}]
  context = SSHKit.context(hosts)
  ```

  Any shared options can be specified in the second argument.
  Here we add a user and port for all hosts.

  ```
  hosts = ["10.0.0.1", "10.0.0.2"]
  options = [user: "admin", port: 2222]
  context = SSHKit.context(hosts, options)
  ```
  """
  def context(hosts, defaults \\ []) do
    hosts =
      hosts
      |> List.wrap()
      |> Enum.map(&host(&1, defaults))

    %Context{hosts: hosts}
  end

  @doc """
  Changes the working directory commands are executed in for the given context.

  Returns a new, derived context for easy chaining.

  ## Example

  Create `/var/www/app/config.json`:

  ```
  "10.0.0.1"
  |> SSHKit.context()
  |> SSHKit.path("/var/www/app")
  |> SSHKit.run("touch config.json")
  ```
  """
  def path(context, path) do
    %Context{context | path: path}
  end

  @doc """
  Changes the file creation mode mask affecting default file and directory
  permissions.

  Returns a new, derived context for easy chaining.

  ## Example

  Create `precious.txt`, readable and writable only for the logged-in user:

  ```
  "10.0.0.1"
  |> SSHKit.context()
  |> SSHKit.umask("077")
  |> SSHKit.run("touch precious.txt")
  ```
  """
  def umask(context, mask) do
    %Context{context | umask: mask}
  end

  @doc """
  Specifies the user under whose name commands are executed.
  That user might be different than the user with which
  ssh connects to the remote host.

  Returns a new, derived context for easy chaining.

  ## Example

  All commands executed in the created `context` will run as `deploy_user`,
  although we use the `login_user` to log in to the remote host:

  ```
  context =
    {"10.0.0.1", port: 3000, user: "login_user", password: "secret"}
    |> SSHKit.context()
    |> SSHKit.user("deploy_user")
  ```
  """
  def user(context, name) do
    %Context{context | user: name}
  end

  @doc """
  Specifies the group commands are executed with.

  Returns a new, derived context for easy chaining.

  ## Example

  All commands executed in the created `context` will run in group `www`:

  ```
  context =
    "10.0.0.1"
    |> SSHKit.context()
    |> SSHKit.group("www")
  ```
  """
  def group(context, name) do
    %Context{context | group: name}
  end

  @doc """
  Defines new environment variables or overrides existing ones
  for a given context.

  Returns a new, derived context for easy chaining.

  ## Examples

  Setting `NODE_ENV=production`:

  ```
  context =
    "10.0.0.1"
    |> SSHKit.context()
    |> SSHKit.env(%{"NODE_ENV" => "production"})

  # Run the npm start script with NODE_ENV=production
  SSHKit.run(context, "npm start")
  ```

  Modifying the `PATH`:

  ```
  context =
    "10.0.0.1"
    |> SSHKit.context()
    |> SSHKit.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH"})

  # Execute the rbenv-installed ruby to print its version
  SSHKit.run(context, "ruby --version")
  ```
  """
  def env(context, map) do
    %Context{context | env: map}
  end

  @doc ~S"""
  Executes a command in the given context.

  Returns a list of tuples, one fore each host in the context.

  The resulting tuples have the form `{:ok, output, exit_code}` –
  as returned by `SSHKit.SSH.run/3`:

  * `exit_code` is the number with which the executed command returned.

      If everything went well, that usually is `0`.

  * `output` is a keyword list of the output collected from the command.

      It has the form:

      ```
      [
        stdout: "output on standard out",
        stderr: "output on standard error",
        stdout: "some more normal output",
        …
      ]
      ```

  ## Example

  Run a command and verify its output:

  ```
  [{:ok, output, 0}] =
    "example.io"
    |> SSHKit.context()
    |> SSHKit.run("echo \"Hello World!\"")

  stdout =
    output
    |> Keyword.get_values(:stdout)
    |> Enum.join()

  assert "Hello World!\n" == stdout
  ```
  """
  def run(context, command, mode \\ :sequential, timeout \\ :infinity) do
    cmd = Context.build(context, command)

    op = fn host ->
      {:ok, conn} = SSH.connect(host.name, host.options)
      res = SSH.run(conn, cmd, [timeout: timeout])
      :ok = SSH.close(conn)
      res
    end

    perform(context.hosts, op, mode)
  end

  defp perform(hosts, op, :sequential) do
    Enum.map(hosts, op)
  end

  defp perform(hosts, op, :parallel) do
    hosts
    |> Enum.map(fn host -> Task.async(fn -> op.(host) end) end)
    |> Enum.map(fn task -> Task.await(task, :infinity) end)
  end

  @doc ~S"""
  Upload a file or files to the given context.

  Returns a list of `:ok` or `{:error, reason}` - one for each host.

  Possible options are:

  * `as: "remote.txt"` - specify the name of the uploaded file/directory
  * all options accepted by `SSHKit.SCP.Upload.transfer/4`

  ## Examples

  Upload all files and folders in current directory to "/workspace":

  ```
  [:ok] =
    "example.io"
    |> SSHKit.context()
    |> SSHKit.path("/workspace")
    |> SSHKit.upload(".", recursive: true)
  ```

  Upload a file to a different name on the remote host:

  ```
  [:ok] =
    "example.io"
    |> SSHKit.context()
    |> SSHKit.upload("local.txt", as: "remote.txt")
  ```
  """
  def upload(context, source, options \\ []) do
    options = Keyword.put(options, :map_cmd, &Context.build(context, &1))

    target = Keyword.get(options, :as, Path.basename(source))

    run = fn host ->
      {:ok, res} =
        SSH.connect(host.name, host.options, fn conn ->
          SCP.upload(conn, source, target, options)
        end)

      res
    end

    Enum.map(context.hosts, run)
  end

  @doc ~S"""
  Download a file or files from the given context.

  Returns a list of `:ok` or `{:error, reason}` - one for each host.

  Possible options are:

  * `as: "local.txt"` - specify the name of the downloaded file/directory
  * all options accepted by `SSHKit.SCP.Download.transfer/4`

  ## Examples

  Download all files and folders in context directory to current working directory:

  ```
  [:ok] =
    "example.io"
    |> SSHKit.context()
    |> SSHKit.path("/workspace")
    |> SSHKit.download(".", recursive: true)
  ```

  Download a file to a different local name:

  ```
  [:ok] =
    "example.io"
    |> SSHKit.context()
    |> SSHKit.download("remote.txt", as: "local.txt")
  ```
  """
  def download(context, source, options \\ []) do
    options = Keyword.put(options, :map_cmd, &Context.build(context, &1))

    target = Keyword.get(options, :as, Path.basename(source))

    run = fn host ->
      {:ok, res} =
        SSH.connect(host.name, host.options, fn conn ->
          SCP.download(conn, source, target, options)
        end)

      res
    end

    Enum.map(context.hosts, run)
  end
end
