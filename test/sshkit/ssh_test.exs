defmodule SSHKit.SSHTest do
  use ExUnit.Case, async: true

  import SSHKit.SSH
  import ExUnit.CaptureLog

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

  defmodule SSHSandboxConnectionSuccess do
    def session_channel(:sandbox, _, _, _), do: {:ok, 0}

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      {:ok, :result}
    end
  end

  defmodule SSHSandboxConnectionError do
    def session_channel(:sandbox, _, _, _), do: {:ok, 0}

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      :failure
    end
  end

  @host "foo.io"
  @user "me"

  describe "connect/2" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "open sandbox connection with given options and keep it open" do
      host = String.to_charlist(@host)
      user = String.to_charlist(@user)
      options = @options ++ [user: @user]
      conn = %SSHKit.SSH.Connection{
        host:        host,
        options:     [user_interaction: false, user: user],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(options, :ssh_modules)
      }

      assert connect(@host, options) == {:ok, conn}
      refute_received :closed_sandbox_connection
    end

    test "log the connection when dry_run is enabled" do
      logged = capture_log fn ->
        connect(@host, [dry_run: true])
      end

      assert logged =~ "[info]  Connect: #{@host}:22"
    end

    test "log the connection when dry_run is enabled and there is a user" do
      logged = capture_log fn ->
        connect(@host, [user: @user, dry_run: true])
      end

      assert logged =~ "[info]  Connect: #{@user}@#{@host}:22"
    end

    test "log the connection when dry_run is enabled with a non-default port" do
      logged = capture_log fn ->
        connect(@host, [dry_run: true, port: 666])
      end

      assert logged =~ "[info]  Connect: #{@host}:666"
    end

    @options [ssh_modules: %{ssh: SSHSandboxError, ssh_connection: :ssh_connection}]
    test "return error and do not attempt to close if connection cannot be opened" do
      assert connect(@host, @options) == {:error, :sandbox}
      refute_received :closed_sandbox_connection
    end

    test "return error and do not attempt to close if no host given" do
      assert connect(nil, @options) == {:error, "No host given."}
      refute_received :closed_sandbox_connection
    end

    test "error if options not provided as List" do
      options = %{user: "me", password: "secret"}
      assert_raise FunctionClauseError, fn -> connect(@host, options) end
    end
  end

  describe "connect/3" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "execute function on open connection" do
      func = fn(conn) ->
        assert conn.ssh_modules == Keyword.get(@options, :ssh_modules)
        42
      end

      assert connect(@host, @options, func) == {:ok, 42}
      assert_received :closed_sandbox_connection
    end

    test "close connection although function errored" do
      func = fn(_conn) -> raise("error") end

      assert_raise RuntimeError, "error", fn -> connect(@host, @options, func) end
      assert_received :closed_sandbox_connection
    end

    @options [ssh_modules: %{ssh: SSHSandboxError, ssh_connection: :ssh_connection}]
    test "error during connect" do
      func = fn(_conn) -> flunk "should never be called" end

      assert connect(@host, @options, func) == {:error, :sandbox}
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

    test "log closing the connection when dry_run is enabled" do
      logged = capture_log fn ->
        {:ok, conn} = connect(@host, [user: @user, dry_run: true])
        assert close(conn) == :ok
      end

      assert logged =~ "[info]  Disconnect: #{@user}@#{@host}:22"
    end
  end

  describe "run/3" do
    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: :ssh_connection}]
    test "error if Channel cannot be opened" do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(@options, :ssh_modules)
      }
      assert run(conn, "uptime") == {:error, :closed}
    end

    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: SSHSandboxConnectionSuccess}]
    test "sucessfully execute command on connection and return result" do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(@options, :ssh_modules)
      }
      assert run(conn, "uptime") == {:ok, :result}
      assert_received :exec_sandbox_connection
    end

    test "log the command execution when dry_run is enabled" do
      logged = capture_log fn ->
        {:ok, conn} = connect(@host, [user: @user, dry_run: true])
        assert run(conn, "uptime") == {:ok, [], 0}
      end

      assert logged =~ "[info]  Command: uptime"
    end

    @options [ssh_modules: %{ssh: SSHSandboxSuccess, ssh_connection: SSHSandboxConnectionError}]
    test "error when execution of command returns failure" do
      conn = %SSHKit.SSH.Connection{
        host:        'test',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: Keyword.get(@options, :ssh_modules)
      }
      assert run(conn, "uptime") == {:error, :failure}
      assert_received :exec_sandbox_connection
    end
  end
end
