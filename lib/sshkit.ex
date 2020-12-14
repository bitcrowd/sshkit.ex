defmodule SSHKit do
  @moduledoc """
  A toolkit for performing tasks on one or more servers.

  ```
  hosts = ["1.eg.io", {"2.eg.io", port: 2222}]

  context =
    SSHKit.context()
    |> SSHKit.path("/var/www/phx")
    |> SSHKit.user("deploy")
    |> SSHKit.group("deploy")
    |> SSHKit.umask("022")
    |> SSHKit.env(%{"NODE_ENV" => "production"})

  [:ok, :ok] = SSHKit.upload(context, ".", recursive: true)
  [{:ok, _, 0}, {:ok, _, 0}] = SSHKit.run(context, "yarn install", mode: :parallel)
  ```
  """

  alias SSHKit.SSH

  alias SSHKit.Context
  alias SSHKit.Host

  @doc """
  TODO

  Takes one or more (remote) hosts and creates an execution context in which
  remote commands can be run. Accepts any form of host specification also
  accepted by `host/1` and `host/2`, i.e. binaries, maps and 2-tuples.
  """
  def connect(host, options \\ []) do
    SSH.connect(host, options)
  end

  def close(conn) do
    SSH.close(conn)
  end

  def run(conn, command, options \\ []) do
    SSH.run(conn, command, options)
  end

  def send(chan, type \\ 0, data) do
    SSH.Channel.send(chan, type, data)
  end

  def stream(chan) do
    Stream.unfold(:cont, fn
      :cont ->
        {:ok, msg} = SSH.Channel.recv(chan) # TODO: timeout?

        value =
          case msg do
            {:exit_signal, ^chan, signal, message, lang} ->
              {:signal, chan, signal, message, lang}

            {:exit_status, ^chan, status} ->
              {:exit, chan, status}

            {:data, ^chan, 0, data} ->
              {:stdout, chan, data}

            {:data, ^chan, 1, data} ->
              {:stderr, chan, data}

            {:eof, ^chan} ->
              {:eof, chan}

            {:closed, ^chan} ->
              {:closed, chan}
          end

        next =
          case value do
            {:closed, _} -> :halt
            _ -> :cont
          end

        {value, next}

      :halt ->
        nil
    end)
  end

  @doc """
  Creates an execution context in which remote commands can be run.

  See `path/2`, `user/2`, `group/2`, `umask/2`, and `env/2`
  for details on how to derive variations of a context.
  """
  def context() do
    %Context{}
  end

  @doc """
  Changes the working directory commands are executed in for the given context.

  Returns a new, derived context for easy chaining.

  ## Example

  Create `/var/www/app/config.json`:

  ```
  SSHKit.context()
  |> SSHKit.path("/var/www/app")
  |> SSHKit.run(conn, "touch config.json")
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
    # TODO
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
    # TODO
  end
end
