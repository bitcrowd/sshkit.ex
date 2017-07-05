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

    def close(_) do
      send self(), :closed_sandbox_connection
      :ok
    end
  end

  setup_all do
    {:ok, host: "foo.io"}
  end

  describe "connect/2" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "open sandbox connection with given options and keep it open", state do
      user = "test"
      options = @options ++ [user: user]
      conn = %SSHKit.SSH.Connection{
        host:        String.to_charlist(state[:host]),
        options:     [user_interaction: false, user: String.to_charlist(user)],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(options, :ssh_modules)
      }

      assert connect(state[:host], options) == {:ok, conn}
      refute_received :closed_sandbox_connection
    end

    @options [ssh_modules: %{ssh: SSHSandboxError, ssh_connection: :ssh_connection}]
    test "return error and do not attempt to close if connection cannot be opened", state do
      assert connect(state[:host], @options) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end

    test "return error and do not attempt to close if no host given" do
      assert connect(nil, @options) == {:error, "No host given."}
      refute_received :closed_sandbox_connection
    end

    test "error if options not provided as List", state do
      options = %{user: "me", password: "secret"}
      assert_raise FunctionClauseError, fn -> connect(state[:host], options) end
    end
  end

  describe "connect/3" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "execute function on open connection", state do
      func = fn(conn) ->
        assert conn.ssh_modules == Keyword.get(@options, :ssh_modules)
        42
      end

      assert connect(state[:host], @options, func) == {:ok, 42}
      assert_received :closed_sandbox_connection
    end

    test "close connection although function errored", state do
      func = fn(_conn) -> raise("error") end

      assert_raise RuntimeError, "error", fn -> connect(state[:host], @options, func) end
      assert_received :closed_sandbox_connection
    end

    @options [ssh_modules: %{ssh: SSHSandboxError, ssh_connection: :ssh_connection}]
    test "error during connect", state do
      func = fn(_conn) -> flunk "should never be called" end

      assert connect(state[:host], @options, func) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end
  end

  describe "close/1" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "call close on the connection" do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(@options, :ssh_modules)
      }

      assert close(conn) == :ok
      assert_received :closed_sandbox_connection
    end
  end
end
