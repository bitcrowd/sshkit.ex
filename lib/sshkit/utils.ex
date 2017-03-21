defmodule SSHKit.Utils do
  def shellescape(value), do: value

  def shellquote(value), do: value

  def charlistify(value) when is_list(value) do
    Enum.map(value, &charlistify/1)
  end
  def charlistify(value) when is_tuple(value) do
    Tuple.to_list(value) |> charlistify() |> List.to_tuple()
  end
  def charlistify(value) when is_binary(value) do
    to_charlist(value)
  end
  def charlistify(value) do
    value
  end
end
