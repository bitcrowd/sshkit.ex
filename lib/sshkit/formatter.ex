defmodule SSHKit.Formatter do
  @moduledoc """
  Output formatting functions for connections.

  To create a new formatter, `use SSHKit.Formatter` and then define your own functions that are
  listed as callbacks below.
  """

  defmacro __using__(_opts) do
    quote do
      @behaviour SSHKit.Formatter
      alias SSHKit.Host
    end
  end

  @callback puts_connect(%SSHKit.Host{}) :: nil
  @callback puts_exec(String.t, String.t) :: nil
  @callback puts_receive(String.t, :stdout | :stderr, String.t) :: nil
end
