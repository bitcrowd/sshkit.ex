defmodule SSHKit.SSHTest do
  use ExUnit.Case, async: true

  import SSHKit.SSH

  setup context do
    ssh_modules = %{
      ssh:            SSHSandboxHelper.ssh(context),
      ssh_connection: SSHSandboxHelper.ssh_connection(context)
    }
    {:ok, [ssh_modules: ssh_modules]}
  end

  describe "connect/2" do
    test "open sandbox connection with given options and keep it open", %{ssh_modules: ssh_modules} do
      options = [user: "me", ssh_modules: ssh_modules]
      conn    = %SSHKit.SSH.Connection{
        host:        'foo.io',
        options:     [user_interaction: false, user: 'me'],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert connect("foo.io", options) == {:ok, conn}
      refute_received :closed_sandbox_connection
    end

    @tag ssh: :error
    test "return error and do not attempt to close if connection cannot be opened", %{ssh_modules: ssh_modules} do
      assert connect("foo.io", ssh_modules: ssh_modules) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end

    test "return error and do not attempt to close if no host given" do
      assert connect(nil) == {:error, "No host given."}
      refute_received :closed_sandbox_connection
    end

    test "error if options not provided as List" do
      options = %{user: "me", password: "secret"}
      assert_raise FunctionClauseError, fn -> connect("foo.io", options) end
    end
  end

  describe "connect/3" do
    test "execute function on open connection", %{ssh_modules: ssh_modules} do
      options = [ssh_modules: ssh_modules]
      func    = fn(conn) ->
        assert conn.ssh_modules == ssh_modules
        42
      end

      assert connect("foo.io", options, func) == {:ok, 42}
      assert_received :closed_sandbox_connection
    end

    test "close connection although function errored", %{ssh_modules: ssh_modules} do
      options = [ssh_modules: ssh_modules]
      func    = fn(_conn) -> raise("error") end

      assert_raise RuntimeError, "error", fn -> connect("foo.io", options, func) end
      assert_received :closed_sandbox_connection
    end

    @tag ssh: :error
    test "error during connect", %{ssh_modules: ssh_modules} do
      options = [ssh_modules: ssh_modules]
      func    = fn(_conn) -> flunk "should never be called" end

      assert connect("foo.io", options, func) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end
  end

  describe "close/1" do
    test "call close on the connection", %{ssh_modules: ssh_modules} do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert close(conn) == :ok
      assert_received :closed_sandbox_connection
    end
  end

  describe "run/3" do
    @tag ssh_connection: :error
    test "error if Channel cannot be opened", %{ssh_modules: ssh_modules} do
      conn    = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert run(conn, "uptime") == {:error, :closed}
    end

    @tag ssh_connection: :failure
    test "error when execution of command returns failure", %{ssh_modules: ssh_modules} do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }
      assert run(conn, "uptime") == {:error, :failure}
      assert_received :exec_sandbox_connection
    end
  end
end
