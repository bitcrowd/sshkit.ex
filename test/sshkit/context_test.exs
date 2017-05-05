defmodule SSHKit.ContextTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context

  @empty %Context{hosts: []}

  describe "build/2" do
    test "build with path" do
      command =
        %Context{@empty | path: "/var/www"}
        |> Context.build("ls -l")

      assert command == "cd /var/www && /usr/bin/env ls -l"
    end

    test "build with env" do
      command =
        %Context{@empty | env: %{"NODE_ENV" => "production", "CI" => "true"}}
        |> Context.build("echo \"hello\"")

      assert command =~ ~r/export/
      assert command =~ ~r/NODE_ENV="production"/
      assert command =~ ~r/CI="true"/
    end

    test "build with env including whitespace" do
      command =
        %Context{@empty | env: %{"CUSTOM" => "env variable"}}
        |> Context.build("echo \"hello\"")

      assert command =~ ~r/export CUSTOM="env variable"/
    end

    test "build with overwritten env" do
      command =
        @empty
        |> SSHKit.env(%{"NODE_ENV" => "production"})
        |> SSHKit.env(%{"CI" => "true"})
        |> Context.build("ls")

      assert command =~ ~r/export CI="true"/
      assert !String.contains?(command, "NODE_ENV")
    end
  end
end
