defmodule SSHKit.ContextTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context

  @empty %Context{}

  describe "new/0" do
    test "returns a new context" do
      context = Context.new()
      assert context == @empty
    end
  end

  describe "path/2" do
    test "sets the path for the context" do
      context = Context.path(@empty, "/var/www/app")
      assert context.path == "/var/www/app"
    end
  end

  describe "umask/2" do
    test "sets the file permission mask for the context" do
      context = Context.umask(@empty, "077")
      assert context.umask == "077"
    end
  end

  describe "user/2" do
    test "sets the user for the context" do
      context = Context.user(@empty, "meg")
      assert context.user == "meg"
    end
  end

  describe "group/2" do
    test "sets the group for the context" do
      context = Context.group(@empty, "stripes")
      assert context.group == "stripes"
    end
  end

  describe "env/2" do
    test "overwrites existing env" do
      context =
        @empty
        |> Context.env(%{"NODE_ENV" => "production"})
        |> Context.env(%{"CI" => "true"})

      assert context.env == %{"CI" => "true"}
    end
  end

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

    test "with all options" do
      command =
        @empty
        |> Map.put(:path, "/app")
        |> Map.put(:user, "me")
        |> Map.put(:group, "crew")
        |> Map.put(:umask, "007")
        |> Map.put(:env, %{"HOME" => "/home/me"})
        |> Context.build("cp $HOME/conf .")

      assert command ==
               ~S{cd /app && umask 007 && sudo -H -n -u me -g crew -- sh -c '(export HOME="/home/me" && /usr/bin/env cp $HOME/conf .)'}
    end
  end
end
