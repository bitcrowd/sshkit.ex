defmodule SSHKit.SSH.ChannelTest do
  use ExUnit.Case, async: true

  import SSHKit.SSH.Channel
  alias SSHKit.SSH.Channel
  alias SSHKit.SSH

  setup context do
    ssh_modules = %{
      ssh:            SSHSandboxHelper.ssh(context),
      ssh_connection: SSHSandboxHelper.ssh_connection(context)
    }
    conn = %SSH.Connection{
      ref:         :sandbox,
      ssh_modules: ssh_modules
    }
    channel = %Channel{
      connection: conn,
      type:       :session,
      id:         :sandbox_channel_id
    }

    {:ok, [conn: conn, channel: channel]}
  end

  describe "open/2" do
    test "open a channel on an SSH.Connection", %{conn: conn, channel: channel} do
      assert open(conn) == {:ok, channel}
      assert_received :opened_sandbox_channel
    end

    @tag ssh_connection: :error
    test "error if channel cannot be opened", %{conn: conn} do
      assert open(conn) == {:error, :closed}
    end
  end

  describe "close/1" do
    test "close the channel's connection", %{channel: channel} do
      assert close(channel) == :ok
      assert_received :closed_sandbox_connection
    end

    @tag ssh_connection: :error
    test "close the channel's connection if it's not even open", %{channel: channel} do
      assert close(channel) == :ok
    end
  end

  describe "exec/3" do
    test "successfully execute a command on the channel", %{channel: channel} do
      assert exec(channel, "command") == :success
      assert_received :exec_sandbox_connection
    end

    test "successfully execute a Charlist command on the channel", %{channel: channel} do
      assert exec(channel, 'command') == :success
      assert_received :exec_sandbox_connection
    end

    @tag ssh_connection: :failure
    test "execute a failing command", %{channel: channel} do
      assert exec(channel, "command") == :failure
      assert_received :exec_sandbox_connection
    end

    @tag ssh_connection: :error
    test "error if command cannot be executed", %{channel: channel} do
      assert exec(channel, "command") == {:error, :closed}
    end
  end

  describe "send/" do
    test "send binary data across channel", %{channel: channel} do
      assert Channel.send(channel, "data")
      assert_received :send_sandbox_connection
    end

    test "send charlist data across channel", %{channel: channel} do
      assert Channel.send(channel, '123')
      assert_received :send_sandbox_connection
    end

    @tag ssh_connection: :error
    test "error when channel not open", %{channel: channel} do
      assert Channel.send(channel, "data") == {:error, :closed}
    end

    @tag ssh_connection: :timeout
    test "error when channel times out", %{channel: channel} do
      assert Channel.send(channel, "data") == {:error, :timeout}
    end
  end

  describe "eof/1" do
    test "send EOF to open channel", %{channel: channel} do
      assert eof(channel) == :ok
    end

    @tag ssh_connection: :error
    test "error when channel not open", %{channel: channel} do
      assert eof(channel) == {:error, :closed}
    end
  end

  describe "recv/2" do
    test "timeout when no message within threshold", %{channel: channel} do
      assert recv(channel, 1) == {:error, :timeout}
    end

    test "receive a message", %{channel: channel} do
      conn    = channel.connection
      message = {:ssh_cm, conn.ref, {:msg, channel.id}}
      Kernel.send(self(), message)

      assert recv(channel, 0) == {:ok, {:msg, channel}}
    end

    test "receive a message with wrong channel id", %{channel: channel} do
      conn             = channel.connection
      wrong_channel_id = 666
      message          = {:ssh_cm, conn.ref, {:msg, wrong_channel_id}}
      Kernel.send(self(), message)

      assert recv(channel, 0) == {:error, :timeout}
    end
  end

  describe "flush/2" do
    test "flush when no messages in channel", %{channel: channel} do
      assert flush(channel, 0) == :ok
    end

    test "flush multiple messages in channel", %{channel: channel} do
      conn = channel.connection
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg1, channel.id}})
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg2, channel.id}})

      assert flush(channel, 0) == :ok
    end

    test "keep other messages in process", %{channel: channel} do
      conn = channel.connection
      msg  = {:ssh_cm, conn.ref, {:msg, 666}}
      Kernel.send(self(), msg)
      messages = :erlang.process_info(self(), :messages)

      assert flush(channel, 0) == :ok
      assert messages == {:messages, [msg]}
    end
  end

  describe "adjust/2" do
    test "error when setting the window size to a string", %{channel: channel} do
      assert_raise FunctionClauseError, ~r/clause matching/, fn ->
        adjust(channel, "hello")
      end
    end

    test "adjust the window size", %{channel: channel} do
      assert adjust(channel, 10) == :ok
      assert_received :adjust_sandbox_channel_window
    end
  end
end
