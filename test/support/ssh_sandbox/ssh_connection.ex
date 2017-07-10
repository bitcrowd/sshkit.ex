defmodule SSHSandbox.SSHConnection do
  @moduledoc false

  defmodule Success do
    @moduledoc false

    def session_channel(:sandbox, _, _, _) do
      send self(), :opened_sandbox_channel
      {:ok, :sandbox_channel_id}
    end

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      :success
    end

    def send(_, _, _, _, _) do
      send self(), :send_sandbox_connection
      :ok
    end

    def send_eof(_, _), do: :ok

    def close(_, _) do
      send self(), :closed_sandbox_connection
      :ok
    end
  end

  defmodule Timeout do
    @moduledoc false

    def session_channel(:sandbox, _, _, _), do: {:ok, :sandbox_channel_id}

    def send(_, _, _, _, _), do: {:error, :timeout}
  end

  defmodule Failure do
    @moduledoc false

    def session_channel(:sandbox, _, _, _), do: {:ok, :sandbox_channel_id}

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      :failure
    end
  end
end
