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

  alias SSHKit.Channel
  alias SSHKit.Connection
  alias SSHKit.Context
  alias SSHKit.Download
  alias SSHKit.Host
  alias SSHKit.Upload

  @doc """
  TODO

  Takes one or more (remote) hosts and creates an execution context in which
  remote commands can be run. Accepts any form of host specification also
  accepted by `host/1` and `host/2`, i.e. binaries, maps and 2-tuples.
  """
  @spec connect(binary(), keyword()) :: {:ok, Connection.t()} | {:error, term()}
  def connect(host, options \\ []) do
    Connection.open(host, options)
  end

  @spec close(Connection.t()) :: :ok
  def close(conn) do
    Connection.close(conn)
  end

  # TODO: Do we need to expose lower-level channel operations here?
  #
  # * Send `eof`?
  # * Subsystem
  # * ppty
  # * …
  #
  # Seems like `send` and `eof` should be enough for the intended high-level use cases.
  # If more fine-grained control is needed, feel free to reach for the `SSHKit.Channel` module.

  @spec exec!(Connection.t(), binary(), keyword()) :: Enumerable.t()
  def exec!(conn, command, options \\ []) do
    # TODO: Separate options for open/exec/recv
    Stream.resource(
      fn ->
        {:ok, chan} = Channel.open(conn, options) # TODO: handle {:error, reason} and raise custom error struct?
        :success = Channel.exec(chan, command) # TODO: timeout?, TODO: Handle :failure and {:error, reason} and raise custom error struct?
        chan
      end,
      fn chan ->
        {:ok, msg} = Channel.recv(chan) # TODO: timeout?, TODO: handle {:error, reason} and raise custom error struct?

        # TODO: Adjust channel window size?

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
            _ -> [value]
          end

        {next, chan}
      end,
      fn chan ->
        :ok = Channel.close(chan)
        :ok = Channel.flush(chan)
      end
    )
  end

  @spec send(Channel.t(), :eof) :: :ok | {:error, term()}
  def send(chan, :eof) do
    Channel.eof(chan)
  end

  @spec send(Channel.t(), :stdout | :stderr, term(), timeout()) :: :ok | {:error, term()}
  def send(chan, type \\ :stdout, data, timeout \\ :infinity)
  def send(chan, :stdout, data, timeout), do: Channel.send(chan, 0, data, timeout)
  def send(chan, :stderr, data, timeout), do: Channel.send(chan, 1, data, timeout)

  @spec run!(Connection.t(), binary(), keyword()) :: [{:stdout, binary()} | {:stderr, binary()}]
  def run!(conn, command, options \\ []) do
    stream = exec!(conn, command, options)

    {status, output} = Enum.reduce(stream, {nil, []}, fn
      {:stdout, _, data}, {status, output} -> {status, [{:stdout, data} | output]}
      {:stderr, _, data}, {status, output} -> {status, [{:stderr, data} | output]}
      {:exit, _, status}, {_, output} -> {status, output}
      _, acc -> acc
    end)

    output = Enum.reverse(output)

    if status != 0, do: raise "Non-zero exit code: #{status}" # TODO: Proper file struct?

    output
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

    # TODO: Close SFTP channel (Upload.stop/1) if there is an error
    with {:ok, upload} <- Upload.start(upload, conn),
         {:ok, upload} <- Upload.loop(upload),
         {:ok, _} <- Upload.stop(upload) do
      :ok
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
