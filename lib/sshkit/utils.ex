defmodule SSHKit.Utils do
  def shellescape(value), do: value

  def shellquote(value), do: value

  def strings_to_charlists(opts) when is_list(opts) do
    Enum.map(opts, fn {k, v} -> {k, charlist(v)} end)    
  end

  defp charlist(value) when is_binary(value), do: to_charlist(value)
  defp charlist(value), do: value
end
