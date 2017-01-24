defmodule SSHKit.FunctionalCase do
  use ExUnit.CaseTemplate

  setup tags do
    # IO.inspect(Map.get(tags, :servers, 1))

    # start docker container(s)
    # set up container(s) with user(s) & key(s)

    on_exit fn ->
      :ok # ensure containers are killed and removed
    end

    :ok
  end
end
