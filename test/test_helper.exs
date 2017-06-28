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

{output, _} = System.cmd("sha1sum", ["--version"])
sha1sum = String.contains?(output, "sha1sum")
unless sha1sum do
  IO.puts """
  It seems like the `sha1sum` command isn't available?
  Please check that sha1sum is installed: `which sha1sum`
  """

  exit({:shutdown, 1})
end



Docker.build!("sshkit-test-sshd", "test/support/docker")

ExUnit.start()
