defmodule SSHSandbox do
  defmodule SSH do
    defmodule Success do
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
      def connect(_, _, _, _), do: {:error, :sandbox}

      def close(_) do
        send self(), :closed_sandbox_connection
        :ok
      end
    end
  end

  defmodule SSHConnection do
    defmodule Success do
      def session_channel(:sandbox, _, _, _) do
        send self(), :opened_sandbox_channel
        {:ok, :sandbox_channel_id}
      end

      def exec(_, _, _, _) do
        send self(), :exec_sandbox_connection
        {:ok, :sandbox_result}
      end

      def close(_, _) do
        send self(), :closed_sandbox_connection
        :ok
      end
    end

    defmodule Failure do
      def session_channel(:sandbox, _, _, _), do: {:ok, :sandbox_channel_id}

      def exec(_, _, _, _) do
        send self(), :exec_sandbox_connection
        :failure
      end
    end
  end

  defmodule ConnectionError do
    def session_channel(:sandbox, _, _, _), do: {:error, :sandbox}

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      :failure
    end
  end

  defmodule ExecutionSuccess do
    def session_channel(:sandbox, _, _, _), do: {:ok, :sandbox_channel_id}

    def exec(_, _, _, _) do
      send self(), :exec_sandbox_connection
      :success
    end
  end

  defmodule ExecutionError do
    def session_channel(:sandbox, _, _, _) do
      send self(), :opened_sandbox_channel
      {:ok, :sandbox_channel_id}
    end

    def exec(_, _, _, _), do: {:error, :sandbox}
  end
end
