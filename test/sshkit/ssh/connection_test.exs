defmodule SSHKit.SSH.ConnectionTest do
  use ExUnit.Case, async: true

  import SSHKit.SSH.Connection
  alias SSHKit.SSH.Connection

  setup context do
    ssh_modules = %{ssh: SSHSandboxHelper.ssh(context)}
    {:ok, [ssh_modules: ssh_modules]}
  end

  describe "open/2" do
    test "open connection", %{ssh_modules: ssh_modules} do
      options = [ssh_modules: ssh_modules]
      conn    = %Connection{
        host:        'foo.io',
        options:     [user_interaction: false],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert open("foo.io", options) == {:ok, conn}
      assert_received :opened_sandbox_connection
    end

    test "open connection on different port with user and password", %{ssh_modules: ssh_modules} do
      options = [port: 666, user: "me", password: "secret", ssh_modules: ssh_modules]
      conn    = %Connection{
        host:        'foo.io',
        options:     [user_interaction: false, user: 'me', password: 'secret'],
        port:        666,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert open("foo.io", options) == {:ok, conn}
      assert_received :opened_sandbox_connection
    end

    test "open connection with user interaction option set to true", %{ssh_modules: ssh_modules} do
      options = [user: "me", password: "secret", user_interaction: true, ssh_modules: ssh_modules]
      conn = %Connection{
        host:        'foo.io',
        options:     [user: 'me', password: 'secret', user_interaction: true],
        port:        22,
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert open("foo.io", options) == {:ok, conn}
      assert_received :opened_sandbox_connection
    end

    test "remove options irrelevant for connect/4", %{ssh_modules: ssh_modules} do
      options = [port: 666, timeout: 1000, user: "me", password: "secret", ssh_modules: ssh_modules]
      {:ok, conn} = open("foo.io", options)
      option_keys = Keyword.keys(conn.options)

      refute :port in option_keys
      refute :timeout in option_keys
      refute :ssh_modules in option_keys
    end

    test "convert option values to Charlists", %{ssh_modules: ssh_modules} do
      options = [user: "me", password: "secret", ssh_modules: ssh_modules]
      {:ok, %Connection{options: conn_options}} = open("foo.io", options)

      assert {:user, 'me'} in conn_options
      assert {:password, 'secret'} in conn_options
    end

    @tag ssh: :error
    test "return error when connection cannot be opened", %{ssh_modules: ssh_modules} do
      options = [ssh_modules: ssh_modules]

      assert open("foo.io", options) == {:error, :sandbox}
      refute_received :opened_sandbox_connection
    end

    test "error if no host given" do
      assert open(nil) == {:error, "No host given."}
    end
  end

  describe "close/1" do
    test "close a connection", %{ssh_modules: ssh_modules} do
      conn = %Connection{
        host:        'foo.io',
        port:        22,
        options:     [user_interaction: false],
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert close(conn) == :ok
      assert_received :closed_sandbox_connection
    end
  end

  describe "reopen/2" do
    test "reopen a connection regardless if already open", %{ssh_modules: ssh_modules} do
      conn = %Connection{
        host:        'foo.io',
        port:        22,
        options:     [user_interaction: false, user: 'me', password: 'secret'],
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert reopen(conn, ssh_modules: ssh_modules) == {:ok, conn}
      assert_received :opened_sandbox_connection
      refute_received :closed_sandbox_connection
    end

    test "reopen connection on new port", %{ssh_modules: ssh_modules} do
      options     = [port: 666, ssh_modules: ssh_modules]
      conn        = %Connection{
        host:        'foo.io',
        port:        22,
        options:     [user_interaction: false, user: 'me', password: 'secret'],
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }
      new_conn    = Map.merge(conn, %{port: 666})

      assert reopen(conn, options) == {:ok, new_conn}
      assert_received :opened_sandbox_connection
    end

    @tag ssh: :error
    test "error when unable to open connection", %{ssh_modules: ssh_modules} do
      options     = [ssh_modules: ssh_modules]
      conn        = %Connection{
        host:        'foo.io',
        port:        22,
        options:     [user_interaction: false],
        ref:         :sandbox,
        ssh_modules: ssh_modules
      }

      assert reopen(conn, options) == {:error, :sandbox}
      refute_received :opened_sandbox_connection
    end
  end
end
