defmodule SSHKit.Utils do
  @moduledoc false

  def shellescape(value), do: value

  def shellquote(value), do: "'#{value}'" # TODO: Proper quoting

  def charlistify(value) when is_list(value) do
    Enum.map(value, &charlistify/1)
  end
  def charlistify(value) when is_tuple(value) do
    value
    |> Tuple.to_list
    |> charlistify()
    |> List.to_tuple()
  end
  def charlistify(value) when is_binary(value) do
    to_charlist(value)
  end
  def charlistify(value) do
    value
  end
end
