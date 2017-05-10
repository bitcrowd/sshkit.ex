defmodule SSHKit.Formatters.SilentFormatter do
  @moduledoc """
  Formatter that doesn't output anything (black hole).
  """

  use SSHKit.Formatter

  def puts_connect(_host), do: nil

  def puts_exec(_uuid, _command), do: nil

  def puts_receive(_uuid, _type, _message), do: nil
end
