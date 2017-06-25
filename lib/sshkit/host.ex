defmodule SSHKit.Host do
  @moduledoc ~S"""
  Provides the data structure holding the information
  about how to connect to a host.

  ## Examples

  ```
  %SSHKit.Host{name: "3.eg.io", options: [port: 2223]}
  |> SSHKit.context()
  |> SSHKit.run("touch base")
  ```
  """
  defstruct [:name, :options]
end
