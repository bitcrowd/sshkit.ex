defmodule SSHKit.ConnectionTest do
  use ExUnit.Case, async: true

  import Mox
  import SSHKit.Connection

  alias SSHKit.Connection

  @core MockErlangSsh

  setup :verify_on_exit!

  describe "open/2" do
    test "opens a connection" do
      expect(@core, :connect, fn host, port, opts, timeout ->
        assert host == 'test.io'
        assert port == 22
        assert opts == [user_interaction: false]
        assert timeout == :infinity
        {:ok, :connection_ref}
      end)

      {:ok, conn} = open("test.io")

      assert conn == %Connection{
               host: 'test.io',
               port: 22,
               options: [user_interaction: false],
               ref: :connection_ref
             }
    end

    test "opens a connection on a different port with user and password" do
      expect(@core, :connect, fn _, port, opts, _ ->
        assert port == 666
        assert opts[:user] == 'me'
        assert opts[:password] == 'secret'
        assert opts[:user_interaction] == false
        {:ok, :ref_with_port_user_pass}
      end)

      {:ok, conn} = open("test.io", port: 666, user: "me", password: "secret")

      assert conn == %Connection{
               host: 'test.io',
               port: 666,
               options: [user_interaction: false, user: 'me', password: 'secret'],
               ref: :ref_with_port_user_pass
             }
    end

    test "opens a connection with user interaction option set to true" do
      expect(@core, :connect, fn _, _, opts, _ ->
        assert opts[:user] == 'me'
        assert opts[:password] == 'secret'
        assert opts[:user_interaction] == true
        {:ok, :ref_with_user_interaction}
      end)

      options = [user: "me", password: "secret", user_interaction: true]

      {:ok, conn} = open("test.io", options)

      assert conn == %Connection{
               host: 'test.io',
               options: [user: 'me', password: 'secret', user_interaction: true],
               port: 22,
               ref: :ref_with_user_interaction
             }
    end

    test "opens a connection with a specific timeout" do
      expect(@core, :connect, fn _, _, _, timeout ->
        assert timeout == 3000
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io", timeout: 3000)
    end

    test "removes options irrelevant for connect/4" do
      expect(@core, :connect, fn _, _, opts, _ ->
        option_keys = Keyword.keys(opts)

        refute :port in option_keys
        refute :timeout in option_keys

        {:ok, :ref}
      end)

      options = [port: 666, timeout: 1000, user: "me", password: "secret"]

      {:ok, _} = open("test.io", options)
    end

    test "converts host to charlist" do
      expect(@core, :connect, fn host, _, _, _ ->
        assert host == 'test.io'
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io")
    end

    test "converts option values to charlists" do
      expect(@core, :connect, fn _, _, opts, _ ->
        assert {:user, 'me'} in opts
        assert {:password, 'secret'} in opts
        {:ok, :ref}
      end)

      {:ok, _} = open("test.io", user: "me", password: "secret")
    end

    test "returns an error when connection cannot be opened" do
      expect(@core, :connect, fn _, _, _, _ ->
        {:error, :failed}
      end)

      assert open("test.io") == {:error, :failed}
    end
  end

  describe "close/1" do
    test "closes a connection" do
      expect(@core, :close, fn ref ->
        assert ref == :connection_ref
        :ok
      end)

      conn = %Connection{
        host: 'foo.io',
        port: 22,
        options: [user_interaction: false],
        ref: :connection_ref
      }

      assert close(conn) == :ok
    end
  end

  describe "reopen/2" do
    test "opens a new connection with the same options as the existing connection" do
      conn = %Connection{
        host: 'test.io',
        port: 22,
        options: [user_interaction: false, user: 'me'],
        ref: :connection_ref
      }

      expect(@core, :connect, fn host, port, opts, _ ->
        assert host == conn.host
        assert port == conn.port
        assert opts == conn.options
        {:ok, :new_connection_ref}
      end)

      new_conn = Map.put(conn, :ref, :new_connection_ref)

      assert reopen(conn) == {:ok, new_conn}
    end

    test "reopens a connection on new port" do
      conn = %Connection{
        host: 'test.io',
        port: 22,
        options: [user_interaction: false, user: 'me'],
        ref: :connection_ref
      }

      expect(@core, :connect, fn _, port, _, _ ->
        assert port == 666
        {:ok, :new_connection_ref}
      end)

      new_conn = Map.merge(conn, %{port: 666, ref: :new_connection_ref})

      assert reopen(conn, port: 666) == {:ok, new_conn}
    end

    test "errors when unable to open connection" do
      conn = %Connection{
        host: 'test.io',
        port: 22,
        options: [user_interaction: false],
        ref: :sandbox
      }

      expect(@core, :connect, fn _, _, _, _ ->
        {:error, :failed}
      end)

      assert reopen(conn) == {:error, :failed}
    end
  end
end
