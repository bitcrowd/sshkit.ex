defmodule SSHKit.ContextTest do
  use ExUnit.Case, async: true

  alias SSHKit.Context

  @empty %Context{hosts: []}

  test "build with path" do
    context = @empty |> Context.push({:cd, "/var/www"})
    assert Context.build(context, "ls -l") == "cd /var/www && /usr/bin/env ls -l"
  end
end
