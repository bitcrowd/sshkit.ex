defmodule SSHKit.SCP.Command do
  @moduledoc false

  import SSHKit.Utils

  def build(mode, path, options) do
    scp = case mode do
      :upload -> 'scp -t'
      :download -> 'scp -f'
    end

    flags = [verbose: '-v', preserve: '-p', recursive: '-r']

    build = fn {key, flag}, cmd ->
      if Keyword.get(options, key, false) do
        '#{cmd} #{flag}'
      else
        cmd
      end
    end

    '#{Enum.reduce(flags, scp, build)} #{shellescape(path)}'
  end
end
