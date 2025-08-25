defmodule SSHKit.SSH.ConnectionTest do
  use ExUnit.Case, async: true
  import Mox

  import SSHKit.SSH.Connection

  alias SSHKit.SSH.Connection
  alias SSHKit.SSH.Connection.ImplMock

  setup do
    Mox.verify_on_exit!()
    {:ok, impl: ImplMock}
  end

  describe "open/2" do
    test "opens a connection", %{impl: impl} do
      impl
      |> expect(:connect, fn host, port, opts, timeout ->
        assert host == ~c"test.io"
        assert port == 22
        assert opts == [user_interaction: false]
        assert timeout == :infinity
        {:ok, :connection_ref}
      end)

      {:ok, conn} = open("test.io", impl: impl)

      assert conn == %Connection{
               host: ~c"test.io",
               port: 22,
               options: [user_interaction: false],
               ref: :connection_ref,
               impl: impl
             }
    end

    test "opens a connection on a different port with user and password", %{impl: impl} do
      impl
      |> expect(:connect, fn _, port, opts, _ ->
        assert port == 666
        assert opts[:user] == ~c"me"
        assert opts[:password] == ~c"secret"
        assert opts[:user_interaction] == false
        {:ok, :ref_with_port_user_pass}
      end)

      {:ok, conn} = open("test.io", port: 666, user: "me", password: "secret", impl: impl)

      assert conn == %Connection{
               host: ~c"test.io",
               port: 666,
               options: [user_interaction: false, user: ~c"me", password: ~c"secret"],
               ref: :ref_with_port_user_pass,
               impl: impl
             }
    end

    test "opens a connection with user interaction option set to true", %{impl: impl} do
      impl
      |> expect(:connect, fn _, _, opts, _ ->
        assert opts[:user] == ~c"me"
        assert opts[:password] == ~c"secret"
        assert opts[:user_interaction] == true
        {:ok, :ref_with_user_interaction}
      end)

      options = [user: "me", password: "secret", user_interaction: true, impl: impl]

      {:ok, conn} = open("test.io", options)

      assert conn == %Connection{
               host: ~c"test.io",
               options: [user: ~c"me", password: ~c"secret", user_interaction: true],
               port: 22,
               ref: :ref_with_user_interaction,
               impl: impl
             }
    end

    test "opens a connection with a specific timeout", %{impl: impl} do
      impl
      |> expect(:connect, fn _, _, _, timeout ->
        assert timeout == 3000
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io", timeout: 3000, impl: impl)
    end

    test "removes options irrelevant for connect/4", %{impl: impl} do
      impl
      |> expect(:connect, fn _, _, opts, _ ->
        option_keys = Keyword.keys(opts)

        refute :port in option_keys
        refute :timeout in option_keys
        refute :impl in option_keys

        {:ok, :ref}
      end)

      options = [port: 666, timeout: 1000, user: "me", password: "secret", impl: impl]

      {:ok, _} = open("test.io", options)
    end

    test "converts host to charlist", %{impl: impl} do
      impl
      |> expect(:connect, fn host, _, _, _ ->
        assert host == ~c"test.io"
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io", impl: impl)
    end

    test "converts option values to charlists", %{impl: impl} do
      impl
      |> expect(:connect, fn _, _, opts, _ ->
        assert {:user, ~c"me"} in opts
        assert {:password, ~c"secret"} in opts
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io", user: "me", password: "secret", impl: impl)
    end

    test "returns an error when connection cannot be opened", %{impl: impl} do
      impl
      |> expect(:connect, fn _, _, _, _ ->
        {:error, :failed}
      end)

      assert open("test.io", impl: impl) == {:error, :failed}
    end

    test "returns an error if no host is given" do
      assert open(nil) == {:error, "No host given."}
    end
  end

  describe "close/1" do
    test "closes a connection", %{impl: impl} do
      impl
      |> expect(:close, fn ref ->
        assert ref == :connection_ref
        :ok
      end)

      conn = %Connection{
        host: ~c"foo.io",
        port: 22,
        options: [user_interaction: false],
        ref: :connection_ref,
        impl: impl
      }

      assert close(conn) == :ok
    end
  end

  describe "reopen/2" do
    test "opens a new connection with the same options as the existing connection", %{impl: impl} do
      conn = %Connection{
        host: ~c"test.io",
        port: 22,
        options: [user_interaction: false, user: ~c"me"],
        ref: :connection_ref,
        impl: impl
      }

      impl
      |> expect(:connect, fn host, port, opts, _ ->
        assert host == conn.host
        assert port == conn.port
        assert opts == conn.options
        {:ok, :new_connection_ref}
      end)

      new_conn = Map.put(conn, :ref, :new_connection_ref)

      assert reopen(conn) == {:ok, new_conn}
    end

    test "reopens a connection on new port", %{impl: impl} do
      conn = %Connection{
        host: ~c"test.io",
        port: 22,
        options: [user_interaction: false, user: ~c"me"],
        ref: :connection_ref,
        impl: impl
      }

      impl
      |> expect(:connect, fn _, port, _, _ ->
        assert port == 666
        {:ok, :new_connection_ref}
      end)

      new_conn = Map.merge(conn, %{port: 666, ref: :new_connection_ref})

      assert reopen(conn, port: 666) == {:ok, new_conn}
    end

    test "errors when unable to open connection", %{impl: impl} do
      conn = %Connection{
        host: ~c"test.io",
        port: 22,
        options: [user_interaction: false],
        ref: :sandbox,
        impl: impl
      }

      impl
      |> expect(:connect, fn _, _, _, _ ->
        {:error, :failed}
      end)

      assert reopen(conn) == {:error, :failed}
    end
  end
end
