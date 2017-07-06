defmodule SystemCommands do
  @moduledoc false

  @doc """
  Returns the command to use to calculate sha1 sums of files and directories
  depending on if the `shasum` command is available in the local system `$PATH`.

  It defaults to `sha1sum`, since that is the command we know to work in
  our test-docker-container.
  """
  def shasum_cmd do
    case which("shasum") do
      {_, 0} -> "shasum"
      _ -> "sha1sum"
    end
  end

  def stat_cmd do
    case :os.type() do
      {:unix, :darwin} -> "stat -f '%z\t%a\t%m'"
      _ -> "stat -c '%s\t%X\t%Y'"
    end
  end

  defp which(command) do
    System.cmd("which", [command], stderr_to_stdout: true)
  end
end
