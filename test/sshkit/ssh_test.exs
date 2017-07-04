defmodule SSHKit.SSHTest do
  use ExUnit.Case, async: true

  import SSHKit.SSH

  defmodule SSHSandboxSuccess do
    def connect(_, _, _, _), do: {:ok, :sandbox}
    def close(_) do
      send self(), :closed_sandbox_connection
      :ok
    end
  end

  defmodule SSHSandboxError do
    def connect(_, _, _, _), do: {:error, :sandbox}
  end

  describe "connect/3" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "execute function on open connection" do
      host = "foo"
      func = fn(conn) ->
        assert conn.ssh_modules == Keyword.get(@options, :ssh_modules)
        42
      end

      assert connect(host, @options, func) == {:ok, 42}
      assert_received :closed_sandbox_connection
    end

    test "close connection although function errored" do
      host = "foo"
      func = fn(_conn) -> raise("error") end

      assert_raise RuntimeError, "error", fn -> connect(host, @options, func) end
      assert_received :closed_sandbox_connection
    end

    @options [ssh_modules: %{ssh: SSHSandboxError, ssh_connection: :ssh_connection}]
    test "error during connect" do
      host = "foo"
      func = fn(_conn) -> flunk "should never be called" end

      assert connect(host, @options, func) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end
  end
end
