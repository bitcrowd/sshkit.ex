defmodule SSHKit.SCP.Directive do
  @moduledoc """
  - "D<mode> 0 <name>" create and enter a directory
  - "C<mode> <length> <name>" create a file
  - "E" leave directory and go up
  - "T<mtime> 0 <atime> 0" preserve file timestamps
  """

  require Bitwise

  def encode(:time, mtime, atime), do: 'T#{mtime} 0 #{atime} 0\n'

  def encode(:directory, mode, name), do: 'D#{perm(mode)} 0 #{name}\n'

  def encode(:regular, mode, size, name), do: 'C#{perm(mode)} #{size} #{name}\n'

  def encode(:up), do: 'E\n'

  defp perm(value) do
    value
    |> Bitwise.band(0o7777)
    |> Integer.to_string(8)
    |> String.pad_leading(4, "0")
  end

  @t ~S"(T)(0|[1-9]\d*) (0|[1-9]\d{0,5}) (0|[1-9]\d*) (0|[1-9]\d{0,5})"
  @f ~S"(C|D)([0-7]{4}) (0|[1-9]\d*) ([^/]+)"
  @e ~S"(E)"

  @regex ~r/\A(?|#{@t}|#{@f}|#{@e})\n\z/

  def decode(buffer) do
    case Regex.run(@regex, buffer, capture: :all_but_first) do
      [op, _, _, name] when op in ["C", "D"] and name in ["..", "."] ->
        nil
      ["C", mode, size, name] ->
        {:regular, oct(mode), dec(size), name}
      ["D", mode, _, name] ->
        {:directory, oct(mode), name}
      ["E"] ->
        {:up}
      ["T", mtime, _, atime, _] ->
        {:time, dec(mtime), dec(atime)}
      nil ->
        nil
    end
  end

  defp int(value, base), do: String.to_integer(value, base)
  defp dec(value), do: int(value, 10)
  defp oct(value), do: int(value, 8)
end
