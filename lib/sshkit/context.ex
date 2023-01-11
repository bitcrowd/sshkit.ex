defmodule SSHKit.Context do
  @moduledoc """
  A context encapsulates the environment for the execution of a task. That is:

  * working directory to start in, see `SSHKit.Context.path/2`
  * user to run as, see `SSHKit.Context.user/2`
  * group, see `SSHKit.Context.group/2`
  * file creation mode mask, see `SSHKit.Context.umask/2`
  * environment variables, see `SSHKit.Context.env/2`

  A context can then be used to run commands, upload or download files:
  See `SSHKit.exec!/3`, `SSHKit.upload/4` and `SSHKit.download/4`.
  """

  import SSHKit.Utils

  defstruct [:env, :path, :umask, :user, :group]

  @type t() :: %__MODULE__{}

  @doc """
  Creates an execution context in which remote commands can be run.

  See `path/2`, `user/2`, `group/2`, `umask/2`, and `env/2`
  for details on how to derive variations of a context.
  """
  def new do
    %__MODULE__{}
  end

  @doc """
  Changes the working directory commands are executed in for the given context.

  Returns a new, derived context for easy chaining.

  ## Example

  Create `/var/www/app/config.json`:

  ```
  {:ok, conn} = SSHKit.connect("10.0.0.1")

  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.path("/var/www/app")

  conn
  |> SSHKit.exec!("touch config.json", context: ctx)
  |> Stream.run()

  :ok = SSHKit.close(conn)
  ```
  """
  def path(context, path) do
    %__MODULE__{context | path: path}
  end

  @doc """
  Changes the file creation mode mask affecting default file and directory
  permissions.

  Returns a new, derived context for easy chaining.

  ## Example

  Create `precious.txt`, readable and writable only for the logged-in user:

  ```
  {:ok, conn} = SSHKit.connect("10.0.0.1")

  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.umask("077")

  conn
  |> SSHKit.exec!("touch precious.txt", context: ctx)
  |> Stream.run()

  :ok = SSHKit.close(conn)
  ```
  """
  def umask(context, mask) do
    %__MODULE__{context | umask: mask}
  end

  @doc """
  Specifies the user under whose name commands are executed.
  That user might be different from the user with which
  you connect to the remote host.

  Returns a new, derived context for easy chaining.

  ## Example

  All commands executed in the created `context` will run as `deploy_user`,
  although we use the `login_user` to log in to the remote host:

  ```
  {:ok, conn} = SSHKit.connect("10.0.0.1", user: "login_user", password: "secret")

  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.user("deploy_user")

  conn
  |> SSHKit.exec!("whoami", context: ctx)
  |> Stream.filter(&(elem(&1) == :stdout))
  |> Stream.each(&IO.puts/1)
  |> Stream.run()

  :ok = SSHKit.close(conn)
  ```
  """
  def user(context, name) do
    %__MODULE__{context | user: name}
  end

  @doc """
  Specifies the group commands are executed with.

  Returns a new, derived context for easy chaining.

  ## Example

  All commands executed in the created `context` will run in group `www`:

  ```
  {:ok, conn} = SSHKit.connect("10.0.0.1")

  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.group("www")

  conn
  |> SSHKit.exec!("id -gn", context: ctx)
  |> Stream.filter(&(elem(&1, 0) == :stdout))
  |> Stream.each(&IO.write/1)
  |> Stream.run()

  :ok = SSHKit.close(conn)
  ```
  """
  def group(context, name) do
    %__MODULE__{context | group: name}
  end

  @doc """
  Defines new environment variables or overrides existing ones
  for a given context.

  Returns a new, derived context for easy chaining.

  ## Examples

  Setting `NODE_ENV=production`:

  ```
  {:ok, conn} = SSHKit.connect("10.0.0.1")

  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.env(%{"NODE_ENV" => "production"})

  # Run the npm start script with NODE_ENV=production
  conn
  |> SSHKit.exec!("npm start", context: ctx)
  |> Stream.run()

  :ok = SSHKit.close(conn)
  ```

  Modifying the `PATH`:

  ```
  ctx =
    SSHKit.Context.new()
    |> SSHKit.Context.env(%{"PATH" => "$HOME/.rbenv/shims:$PATH"})

  # Execute the rbenv-installed ruby to print its version
  conn
  |> SSHKit.exec!(conn, "ruby --version", context: ctx)
  |> Stream.run()
  ```
  """
  def env(context, map) do
    %__MODULE__{context | env: map}
  end

  @doc """
  Compiles an executable command string for running the given `command`
  in the provided `context`.

  ## Examples

      iex> %SSHKit.Context{path: "/var/www"} |> SSHKit.Context.build("ls")
      "cd /var/www && /usr/bin/env ls"

      iex> %SSHKit.Context{user: "me"} |> SSHKit.Context.build("whoami")
      "sudo -H -n -u me -- sh -c '/usr/bin/env whoami'"
  """
  def build(context, command) do
    "/usr/bin/env #{command}"
    |> add(:export, context.env)
    |> add(:sudo, context.user, context.group)
    |> add(:umask, context.umask)
    |> add(:cd, context.path)
  end

  defp add(command, :sudo, nil, nil), do: command

  defp add(command, :sudo, username, nil),
    do: "sudo -H -n -u #{username} -- sh -c #{shellquote(command)}"

  defp add(command, :sudo, nil, groupname),
    do: "sudo -H -n -g #{groupname} -- sh -c #{shellquote(command)}"

  defp add(command, :sudo, username, groupname),
    do: "sudo -H -n -u #{username} -g #{groupname} -- sh -c #{shellquote(command)}"

  defp add(command, :export, nil), do: command
  defp add(command, :export, env) when env == %{}, do: command

  defp add(command, :export, env) do
    exports = Enum.map_join(env, " ", fn {name, value} -> "#{name}=\"#{value}\"" end)
    "(export #{exports} && #{command})"
  end

  defp add(command, :umask, nil), do: command
  defp add(command, :umask, mask), do: "umask #{mask} && #{command}"

  defp add(command, :cd, nil), do: command
  defp add(command, :cd, path), do: "cd #{path} && #{command}"
end
