defmodule Docker do
  def build!(tag, path) do
    {_, 0} = System.cmd("docker", ["build", "--tag", tag, path])
  end

  def ready? do
    case System.cmd("docker", ["info"], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end
end
