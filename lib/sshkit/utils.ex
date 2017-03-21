defmodule SSHKit.Utils do
  def shellescape(value), do: value

  def shellquote(value), do: value

  def charlistify(value) do
    cond do
      Keyword.keyword?(value) -> Enum.map(value, fn {k, v} -> {k, charlistify(v)} end)
      is_list(value) -> Enum.map(value, &charlistify/1)
      is_binary(value) -> to_charlist(value)
      true -> value
    end
  end
end
