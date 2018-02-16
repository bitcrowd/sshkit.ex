defmodule SSHKitTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context
  alias SSHKit.Host

  @empty %Context{hosts: []}

  @context_simple %Context{hosts: [
                    %Host{name: "10.0.0.1", options: []},
                    %Host{name: "10.0.0.2", options: []},
                    %Host{name: "10.0.0.3", options: []}
                  ]}
  @context_options %Context{hosts: [
                    %Host{name: "10.0.0.1", options: [user: "user"]},
                    %Host{name: "10.0.0.2", options: [user: "user"]},
                    %Host{name: "10.0.0.3", options: [user: "user"]}
                  ]}
  @context_merged_options %Context{hosts: [
                    %Host{name: "10.0.0.1", options: [user: "user", password: "123"]},
                    %Host{name: "10.0.0.2", options: [user: "user"]},
                    %Host{name: "10.0.0.3", options: [user: "user"]}
                  ]}
  @options [user: "user"]

  describe "host/2" do
    test "creates a host from a hostname (binary) and options" do
      assert SSHKit.host("10.0.0.1", user: "me") == %Host{name: "10.0.0.1", options: [user: "me"]}
    end

    test "creates a host from a map with :name and :options" do
      input = %{name: "10.0.0.1", options: [user: "me"]}
      assert SSHKit.host(input) == %Host{name: "10.0.0.1", options: [user: "me"]}
    end

    test "creates a host from a tuple" do
      input = {"10.0.0.1", user: "me"}
      assert SSHKit.host(input) == %Host{name: "10.0.0.1", options: [user: "me"]}
    end
  end

  describe "context/2" do
    test "creates a context from a single hostname (binary)" do
      context = SSHKit.context("10.0.0.1")
      hosts = [%Host{name: "10.0.0.1", options: []}]
      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a single map with :name and :options" do
      context = SSHKit.context(%{name: "10.0.0.1", options: [user: "me"]})
      hosts = [%Host{name: "10.0.0.1", options: [user: "me"]}]
      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a single tuple" do
      context = SSHKit.context({"10.0.0.1", user: "me"})
      hosts = [%Host{name: "10.0.0.1", options: [user: "me"]}]
      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a list of hostnames (binaries)" do
      context = SSHKit.context(["10.0.0.1", "10.0.0.2"])

      hosts = [
        %Host{name: "10.0.0.1", options: []},
        %Host{name: "10.0.0.2", options: []}
      ]

      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a list of maps with :name and :options" do
      context =
        SSHKit.context([
          %{name: "10.0.0.1", options: [user: "me"]},
          %{name: "10.0.0.2", options: []}
        ])

      hosts = [
        %Host{name: "10.0.0.1", options: [user: "me"]},
        %Host{name: "10.0.0.2", options: []}
      ]

      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a list of tuples" do
      context =
        SSHKit.context([
          {"10.0.0.1", [user: "me"]},
          {"10.0.0.2", []}
        ])

      hosts = [
        %Host{name: "10.0.0.1", options: [user: "me"]},
        %Host{name: "10.0.0.2", options: []}
      ]

      assert context == %Context{hosts: hosts}
    end

    test "creates a context from a mixed list" do
      context =
        SSHKit.context([
          %Host{name: "10.0.0.4", options: [user: "me"]},
          %{name: "10.0.0.3", options: [password: "three"]},
          {"10.0.0.2", port: 2222},
          "10.0.0.1"
        ])

      hosts = [
        %Host{name: "10.0.0.4", options: [user: "me"]},
        %Host{name: "10.0.0.3", options: [password: "three"]},
        %Host{name: "10.0.0.2", options: [port: 2222]},
        %Host{name: "10.0.0.1", options: []}
      ]

      assert context == %Context{hosts: hosts}
    end

    test "includes shared options" do
      hosts = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
      context = SSHKit.context(hosts, @options)
      assert context == @context_options
    end

    test "merges shared options" do
      hosts = [
        %{name: "10.0.0.1", options: [password: "123"]},
        "10.0.0.2",
        "10.0.0.3"
      ]
      context = SSHKit.context(hosts, @options)
      assert context == @context_merged_options
    end

    test "does not override host options with shared options" do
      expected_context = %Context{hosts: [
          %Host{name: "10.0.0.1", options: [user: "host_user"]},
          %Host{name: "10.0.0.2", options: [user: "user"]}
        ]}
      hosts = [
        %{name: "10.0.0.1", options: [user: "host_user"]},
        "10.0.0.2"
      ]
      context = SSHKit.context(hosts, @options)
      assert context == expected_context
    end
  end

  describe "env/2" do
    test "overwrites existing env" do
      context =
        @empty
        |> SSHKit.env(%{"NODE_ENV" => "production"})
        |> SSHKit.env(%{"CI" => "true"})

      assert context.env == %{"CI" => "true"}
    end
  end
end
