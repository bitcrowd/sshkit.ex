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
  alias SSHKit.Upload

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

  def stream!(chan) do
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
  def upload(conn, source, target, options \\ []) do
    upload = Upload.init(source, target, options)

    with {:ok, upload} <- Upload.start(upload, conn) do
      Upload.loop(upload)
    end
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
  def download(conn, source, options \\ []) do
    # TODO
  end
end
