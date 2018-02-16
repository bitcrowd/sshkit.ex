defmodule SSHKitTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context
  alias SSHKit.Host

  @empty %Context{hosts: []}

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
      context =
        [{"10.0.0.1", user: "me"}, "10.0.0.2"]
        |> SSHKit.context(port: 2222)

      hosts = [
        %Host{name: "10.0.0.1", options: [port: 2222, user: "me"]},
        %Host{name: "10.0.0.2", options: [port: 2222]}
      ]

      assert context == %Context{hosts: hosts}
    end

    test "does not override host options with shared options" do
      context =
        [{"10.0.0.1", user: "other"}, "10.0.0.2"]
        |> SSHKit.context(user: "me")

      hosts = [
        %Host{name: "10.0.0.1", options: [user: "other"]},
        %Host{name: "10.0.0.2", options: [user: "me"]}
      ]

      assert context == %Context{hosts: hosts}
    end
  end

  describe "path/2" do
    test "sets the path for the context" do
      context = SSHKit.path(@empty, "/var/www/app")
      assert context.path == "/var/www/app"
    end
  end

  describe "umask/2" do
    test "sets the file permission mask for the context" do
      context = SSHKit.umask(@empty, "077")
      assert context.umask == "077"
    end
  end

  describe "user/2" do
    test "sets the user for the context" do
      context = SSHKit.user(@empty, "meg")
      assert context.user == "meg"
    end
  end

  describe "group/2" do
    test "sets the group for the context" do
      context = SSHKit.group(@empty, "stripes")
      assert context.group == "stripes"
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
