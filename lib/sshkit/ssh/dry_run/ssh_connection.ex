defmodule SSHKit.SSH.DryRun.SSHConnection do
  @moduledoc false

  require Logger

  @ssh_channel_id :dry_run_channel
  def session_channel(_ref, _ini_window_size, _max_packet_size, _timeout) do
    {:ok, @ssh_channel_id}
  end


  def exec(ref, id, command, _timeout) do
    Logger.info("Command: #{command}")

    send self(), {:ssh_cm, ref, {:exit_status, id, 0}}
    send self(), {:ssh_cm, ref, {:closed, id}}
    :success
  end

  def close(_ref, _id), do: :ok
  def send_eof(_ref, _id), do: :ok
  def adjust_window(_ref, _id, _size), do: :ok
  def send(_ref, _id, _type, _data, _timeout), do: :ok
end
