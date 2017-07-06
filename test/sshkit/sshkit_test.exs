defmodule SSHKitTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context
  alias SSHKit.Host

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

  describe "context/2" do
    test "creates with list of binaries" do
      hosts = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
      context = SSHKit.context(hosts)

      assert context == @context_simple
    end

    test "creates with list of Maps" do
      hosts = [
        %{name: "10.0.0.1", options: []},
        %{name: "10.0.0.2", options: []},
        %{name: "10.0.0.3", options: []}
      ]
      context = SSHKit.context(hosts)

      assert context == @context_simple
    end

    test "creates with mixed list" do
      hosts = [
        "10.0.0.1",
        %{name: "10.0.0.2", options: []},
        %Host{name: "10.0.0.3", options: []}
      ]
      context = SSHKit.context(hosts)

      assert context == @context_simple
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
end
