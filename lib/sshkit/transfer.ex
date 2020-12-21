defmodule SSHKit.Transfer do
  @moduledoc false

  alias SSHKit.Connection

  @spec stream!(Connection.t(), struct(), keyword()) :: Enumerable.t()
  def stream!(conn, transfer, options \\ []) do
    module = mod(transfer)

    Stream.resource(
      fn ->
        {:ok, transfer} = module.start(transfer, conn)
        transfer
      end,
      fn transfer ->
        if module.done?(transfer) do
          {:halt, transfer}
        else
          {:ok, transfer} = module.continue(transfer)
          {[transfer], transfer}
        end
      end,
      fn transfer ->
        {:ok, transfer} = module.stop(transfer)
      end
    )
  end

  defp mod(%{__struct__: name}), do: name
end
