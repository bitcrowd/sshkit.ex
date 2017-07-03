unless Docker.ready? do
  IO.puts """
  It seems like Docker isn't running?

  Please check:

  1. Docker is installed: `docker version`
  2. On OS X and Windows: `docker-machine start`
  3. Environment is set up: `eval $(docker-machine env)`
  """

  exit({:shutdown, 1})
end

shasum_command = SystemCommands.shasumcmd()
try do
  System.cmd(shasum_command, ["--version"])
rescue
  error in ErlangError ->
    IO.puts """
    An error happened while executing #{shasum_command} (#{error.original}).

    It seems like the `#{shasum_command}` command isn't available?
    Please check that #{shasum_command} is installed: `which #{shasum_command}`
    """
    exit({:shutdown, 1})
end

Docker.build!("sshkit-test-sshd", "test/support/docker")

ExUnit.start()
