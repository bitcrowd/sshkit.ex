defmodule SSHSandbox.SSH do
  @moduledoc false

  defmodule Success do
    @moduledoc false

    def connect(_, _, _, _) do
      send self(), :opened_sandbox_connection
      {:ok, :sandbox}
    end

    def close(_) do
      send self(), :closed_sandbox_connection
      :ok
    end
  end

  defmodule Error do
    @moduledoc false

    def connect(_, _, _, _), do: {:error, :sandbox}

    def close(_) do
      send self(), :closed_sandbox_connection
      :ok
    end
  end
end
