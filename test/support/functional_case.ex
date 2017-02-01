defmodule SSHKit.FunctionalCase do
  use ExUnit.CaseTemplate

  setup tags do
    count = Map.get(tags, :boot, 1)
    debug = Map.get(tags, :debug, false)

    hosts = Enum.map(1..count, &(init(boot(conf(&1, debug)))))

    on_exit fn -> kill(hosts) end

    {:ok, hosts: hosts}
  end

  def conf(index, debug) do
    cmd = "/usr/sbin/sshd"
    args = ["-D"]

    # For debugging, let sshd be more verbose:
    # args = ["-D", "-d", "-d", "-d"]

    # Follow the log output of a specific container:
    # docker logs --follow [CONTAINER-ID]

    %{cmd: cmd, args: args}
  end

  def boot(config = %{cmd: cmd, args: args}) do
    options = ["--rm", "--detach", "--publish-all"]

    id = Docker.run!(options, "sshkit-test-sshd", cmd, args)

    ip = Docker.host

    port =
      Docker.cmd!("port", [id, "22/tcp"])
      |> String.split(":")
      |> List.last
      |> String.to_integer

    Map.merge(config, %{id: id, ip: ip, port: port})
  end

  def init(host) do
    # TODO: Set up container with user & keys, e.g. via Docker.exec!
    Map.merge(host, %{user: nil, key: nil, password: nil})
  end

  def kill(hosts) do
    running = Enum.map(hosts, &(Map.get(&1, :id)))
    killed = Docker.kill!(running)
    diff = running -- killed
    if Enum.empty?(diff), do: :ok, else: {:error, diff}
  end
end
