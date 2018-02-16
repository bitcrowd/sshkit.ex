defmodule SSHKit.ContextTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context

  @empty %Context{hosts: []}

  describe "build/2" do
    test "with user" do
      command =
        %Context{@empty | user: "me"}
        |> Context.build("whoami")

      assert command == "sudo -H -n -u me -- sh -c '/usr/bin/env whoami'"
    end

    test "with group" do
      command =
        %Context{@empty | group: "crew"}
        |> Context.build("id -g -n")

      assert command == "sudo -H -n -g crew -- sh -c '/usr/bin/env id -g -n'"
    end

    test "with user and group" do
      command =
        %Context{@empty | user: "me", group: "crew"}
        |> Context.build("id")

      assert command == "sudo -H -n -u me -g crew -- sh -c '/usr/bin/env id'"
    end

    test "with env" do
      command =
        %Context{@empty | env: %{"NODE_ENV" => "production", "CI" => "true"}}
        |> Context.build("echo \"hello\"")

      assert command =~ ~r/\A\(export .+ && \/usr\/bin\/env echo "hello"\)\z/
      assert command =~ ~r/NODE_ENV="production"/
      assert command =~ ~r/CI="true"/
    end

    test "with env including whitespace" do
      command =
        %Context{@empty | env: %{"CUSTOM" => "env variable"}}
        |> Context.build("echo \"hello\"")

      assert command =~ ~r/export CUSTOM="env variable"/
    end

    test "with nil env" do
      command =
        %Context{@empty | env: nil}
        |> Context.build("ls")

      assert command == "/usr/bin/env ls"
    end

    test "with empty env" do
      command =
        %Context{@empty | env: %{}}
        |> Context.build("ls")

      assert command == "/usr/bin/env ls"
    end

    test "with umask" do
      command =
        %Context{@empty | umask: "077"}
        |> Context.build("touch precious.txt")

      assert command == "umask 077 && /usr/bin/env touch precious.txt"
    end

    test "with path" do
      command =
        %Context{@empty | path: "/var/www"}
        |> Context.build("ls -l")

      assert command == "cd /var/www && /usr/bin/env ls -l"
    end
  end
end
