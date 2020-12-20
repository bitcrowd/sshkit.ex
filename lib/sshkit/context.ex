defmodule SSHKit.Context do
  @moduledoc """
  A context encapsulates the environment for the execution of a task. That is:

  * working directory to start in, see `SSHKit.path/2`
  * user to run as, see `SSHKit.user/2`
  * group, see `SSHKit.group/2`
  * file creation mode mask, see `SSHKit.umask/2`
  * environment variables, see `SSHKit.env/2`

  A context can then be used to run commands, upload or download files:
  See `SSHKit.run/2`, `SSHKit.upload/3` and `SSHKit.download/3`.
  """

  import SSHKit.Utils

  defstruct env: nil, path: nil, umask: nil, user: nil, group: nil

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
  SSHKit.context()
  |> SSHKit.path("/var/www/app")
  |> SSHKit.run(conn, "touch config.json")
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
  "10.0.0.1"
  |> SSHKit.context()
  |> SSHKit.umask("077")
  |> SSHKit.run("touch precious.txt")
  ```
  """
  def umask(context, mask) do
    %__MODULE__{context | umask: mask}
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
    %__MODULE__{context | user: name}
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
    %__MODULE__{context | group: name}
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
