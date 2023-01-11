defmodule SSHKit.FunctionalCase do
  @moduledoc false

  use ExUnit.CaseTemplate

  import SSHKit.FunctionalCaseHelpers

  @image "sshkit-test-sshd"
  @cmd "/usr/sbin/sshd"
  @args ["-D", "-e"]

  using do
    quote do
      import SSHKit.FunctionalCaseHelpers
      import SSHKit.FunctionalAssertionHelpers

      @moduletag :functional

      setup do
        # Stub mocks with implementations delegating to the original Erlang
        # modules, essentially "unmocking" them unless explicit expectations
        # are set up.
        Mox.stub_with(MockErlangSsh, ErlangSsh)
        Mox.stub_with(MockErlangSshConnection, ErlangSshConnection)
        Mox.stub_with(MockErlangSshSftp, ErlangSshSftp)
        :ok
      end
    end
  end

  defmodule Host do
    @moduledoc false
    defstruct [:id, :name, options: []]
  end

  setup tags do
    specs = Map.get(tags, :boot, [])
    hosts = Enum.map(specs, &start!/1)
    on_exit(fn -> kill!(hosts) end)
    {:ok, hosts: hosts}
  end

  def start!(options) do
    boot!(@image, @cmd, @args) |> init!(options)
  end

  def boot!(image, cmd, args) do
    id = Docker.run!(["--rm", "--publish-all", "--detach"], image, cmd, args)

    ip = Docker.host()

    port =
      "port"
      |> Docker.cmd!([id, "22/tcp"])
      |> String.split(":")
      |> List.last()
      |> String.to_integer()

    %Host{id: id, name: ip, options: [port: port]}
  end

  def init!(host, options) do
    options =
      host.options
      |> Keyword.merge(silently_accept_hosts: true, timeout: 5000)
      |> Keyword.merge(options)

    user = options[:user]
    password = options[:password]

    if user != nil, do: adduser!(host, user)
    if user != nil && password != nil, do: chpasswd!(host, user, password)

    %Host{host | options: options}
  end

  def kill!(hosts) do
    running = Enum.map(hosts, &Map.get(&1, :id))
    killed = Docker.kill!(running)
    diff = running -- killed
    if Enum.empty?(diff), do: :ok, else: {:error, diff}
  end
end
