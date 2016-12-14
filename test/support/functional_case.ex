defmodule SSHKit.FunctionalCase do
  use ExUnit.CaseTemplate

  setup tags do
    IO.inspect(Map.get(tags, :servers, 1))

    # use docker remote API?
    # https://docs.docker.com/engine/reference/api/docker_remote_api/
    # https://docs.docker.com/engine/reference/api/docker_remote_api_v1.24/

    # ensure docker image is built
    # start docker container

    on_exit fn ->
      # ensure docker container is killed and removed
    end

    :ok
  end
end
