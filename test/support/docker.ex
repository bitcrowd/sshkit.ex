defmodule Docker do
  def ready? do
    case cmd("info", [], stderr_to_stdout: true) do
      {_, 0} -> true
      _ -> false
    end
  end

  def host do
    case System.get_env("DOCKER_HOST") do
      addr when is_binary(addr) -> Map.get(URI.parse(addr), :host)
      nil -> "127.0.0.1"
    end
  end

  def build!(tag, path) do
    output = cmd!("build", ["--tag", tag, path])
    Regex.run(~r{([0-9a-f]+)$}, output) |> List.last
  end

  def run!(options \\ [], image, command \\ nil, args \\ [])

  def run!(options, image, nil, args) do
    cmd!("run", options ++ [image] ++ args)
  end

  def run!(options, image, command, args) do
    cmd!("run", options ++ [image, command] ++ args)
  end

  def exec!(options \\ [], container, command, args \\ []) do
    cmd!("exec", options ++ [container, command] ++ args)
  end

  def kill!(options \\ [], containers) do
    cmd!("kill", options ++ containers) |> String.split("\n")
  end

  def cmd(command, args \\ [], options \\ []) do
    System.cmd("docker", [command | args], options)
  end

  def cmd!(command, args \\ [], options \\ []) do
    case cmd(command, args, options) do
      {output, 0} -> String.trim(output)
      {_, status} -> raise("Failed on docker #{command} #{inspect(args)} (#{status})")
    end
  end
end
