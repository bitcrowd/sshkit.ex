defmodule SSHKit.SSHTest do
  use ExUnit.Case, async: true
  import Mox

  import SSHKit.SSH

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Channel

  @host "test.io"
  @user "me"

  setup do
    Mox.verify_on_exit!
  end

  describe "connect/2" do
    setup do
      {:ok, impl: Connection.ImplMock}
    end

    test "opens a connection with the given options and keeps it open", %{impl: impl} do
      impl |> expect(:connect, fn (host, port, opts, timeout) ->
        assert host == 'test.io'
        assert port == 2222
        assert opts == [user_interaction: false, user: 'me']
        assert timeout == :infinity
        {:ok, :connection_ref}
      end)

      {:ok, conn} = connect(@host, user: @user, port: 2222, impl: impl)

      assert conn == %Connection{
        host:    'test.io',
        options: [user_interaction: false, user: 'me'],
        port:    2222,
        ref:     :connection_ref,
        impl:    impl
      }
    end

    test "returns an error if connection cannot be opened", %{impl: impl} do
      impl |> expect(:connect, fn (_, _, _, _) -> {:error, :timeout} end)
      assert connect(@host, impl: impl) == {:error, :timeout}
    end

    test "returns an error if no host given" do
      assert connect(nil) == {:error, "No host given."}
    end

    test "returns an error if options not provided as list" do
      options = %{user: @user, password: "secret"}
      assert_raise FunctionClauseError, fn -> connect(@host, options) end
    end
  end

  describe "connect/3" do
    setup do
      {:ok, impl: Connection.ImplMock}
    end

    test "executes function on open connection", %{impl: impl} do
      impl
      |> expect(:connect, fn (_, _, _, _) -> {:ok, :opened_connection_ref} end)
      |> expect(:close, fn :opened_connection_ref -> :ok end)

      fun = fn conn ->
        assert conn.ref == :opened_connection_ref
        42
      end

      assert connect(@host, [impl: impl], fun) == {:ok, 42}
    end

    test "closes connection although function errored", %{impl: impl} do
      impl
      |> expect(:connect, fn (_, _, _, _) -> {:ok, :opened_connection_ref} end)
      |> expect(:close, fn :opened_connection_ref -> :ok end)

      fun = fn _ -> raise(RuntimeError, message: "error") end

      assert_raise RuntimeError, "error", fn ->
        connect(@host, [impl: impl], fun)
      end
    end

    test "returns connection errors", %{impl: impl} do
      impl |> expect(:connect, fn (_, _, _, _) -> {:error, :timeout} end)
      fun = fn _ -> flunk "should never be called" end
      assert connect(@host, [impl: impl], fun) == {:error, :timeout}
    end
  end

  describe "close/1" do
    setup do
      {:ok, impl: Connection.ImplMock}
    end

    test "closes the connection", %{impl: impl} do
      conn = %SSHKit.SSH.Connection{
        host:    'test.io',
        port:    22,
        options: [user_interaction: false],
        ref:     :connection_ref,
        impl:    impl
      }

      impl |> expect(:close, fn ref ->
        assert ref == conn.ref
        :ok
      end)

      assert close(conn) == :ok
    end
  end

  describe "run/3" do
    setup do
      conn = %Connection{ref: :cref, impl: Connection.ImplMock}
      {:ok, conn: conn, impl: Channel.ImplMock}
    end

    test "captures output and exit status by default", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn (:cref, _, _, :infinity) -> {:ok, 11} end)
      |> expect(:exec, fn (:cref, 11, 'try', :infinity) -> :success end)
      |> expect(:adjust_window, 2, fn (:cref, 11, _) -> :ok end)

      send(self(), {:ssh_cm, conn.ref, {:data, 11, 0, "out"}})
      send(self(), {:ssh_cm, conn.ref, {:data, 11, 1, "err"}})
      send(self(), {:ssh_cm, conn.ref, {:exit_status, 11, 127}})
      send(self(), {:ssh_cm, conn.ref, {:closed, 11}})

      assert run(conn, "try", impl: impl) == {:ok, [stdout: "out", stderr: "err"], 127}
    end

    test "accepts a custom handler function and accumulator", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn (:cref, _, _, _) -> {:ok, 31} end)
      |> expect(:exec, fn (:cref, 31, 'cmd', _) -> :success end)
      |> expect(:send, fn (:cref, 31, 0, "PING", _) -> :ok end)
      |> expect(:adjust_window, fn (:cref, 31, _) -> :ok end)
      |> expect(:close, fn (:cref, 31) -> :ok end)

      send(self(), {:ssh_cm, conn.ref, {:data, 31, 0, "PONG"}})

      ini = {:cont, "PING", ["START"]}

      fun = fn (msg, acc) ->
        case msg do
          {:data, _, 0, data} -> {:halt, [data | acc]}
          _ -> {:cont, "NOPE", ["FAILED" | acc]}
        end
      end

      assert run(conn, "cmd", acc: ini, fun: fun, impl: impl) == ["PONG", "START"]
    end

    test "accepts a timeout value", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn (_, _, _, 500) -> {:ok, 61} end)
      |> expect(:exec, fn (_, _, _, 500) -> :success end)
      |> expect(:send, fn (_, _, _, _, 500) -> {:error, :timeout} end)
      |> expect(:close, fn (_, _) -> :ok end)

      acc = {:cont, "INIT", {[], nil}}

      assert run(conn, "cmd", acc: acc, timeout: 500, impl: impl) == {:error, :timeout}
    end

    test "returns an error if channel cannot be opened", %{conn: conn, impl: impl} do
      impl |> expect(:session_channel, fn (_, _, _, _) -> {:error, :timeout} end)
      assert run(conn, "uptime", impl: impl) == {:error, :timeout}
    end

    test "returns an error if command fails to execute", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn (_, _, _, _) -> {:ok, 13} end)
      |> expect(:exec, fn (_, _, _, _) -> :failure end)

      assert run(conn, "uptime", impl: impl) == {:error, :failure}
    end
  end
end
