defmodule SSHKit.ChannelTest do
  use ExUnit.Case, async: true

  import Mox
  import SSHKit.Channel

  alias SSHKit.Channel
  alias SSHKit.Connection

  @core MockErlangSshConnection

  setup :verify_on_exit!

  setup do
    conn = %Connection{ref: :test_connection}
    chan = %Channel{connection: conn, type: :session, id: 1}

    {:ok, conn: conn, chan: chan}
  end

  describe "open/2" do
    test "opens a channel on a connection", %{conn: conn} do
      expect(@core, :session_channel, fn connection_ref,
                                         ini_window_size,
                                         max_packet_size,
                                         timeout ->
        assert connection_ref == conn.ref
        assert ini_window_size == 128 * 1024
        assert max_packet_size == 32 * 1024
        assert timeout == :infinity
        {:ok, 0}
      end)

      {:ok, chan} = open(conn)

      assert chan == %Channel{connection: conn, type: :session, id: 0}
    end

    test "opens a channel with a specific timeout", %{conn: conn} do
      expect(@core, :session_channel, fn _, _, _, timeout ->
        assert timeout == 3000
        {:ok, 0}
      end)

      {:ok, _} = open(conn, timeout: 3000)
    end

    test "returns an error if channel cannot be opened", %{conn: conn} do
      expect(@core, :session_channel, fn _, _, _, _ -> {:error, :timeout} end)
      assert open(conn) == {:error, :timeout}
    end
  end

  describe "subsystem/3" do
    test "requests a subsystem", %{chan: chan} do
      expect(@core, :subsystem, fn connection_ref, channel_id, subsystem, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert subsystem == 'example-subsystem'
        assert timeout == :infinity
        :success
      end)

      assert :success == subsystem(chan, "example-subsystem")
    end

    test "requests a subsystem with a specific timeout", %{chan: chan} do
      expect(@core, :subsystem, fn _, _, _, timeout ->
        assert timeout == 3000
        :success
      end)

      assert :success == subsystem(chan, "example-subsystem", timeout: 3000)
    end

    test "returns a failure if the subsystem could not be initialized", %{chan: chan} do
      expect(@core, :subsystem, fn _, _, _, _ -> :failure end)
      assert :failure = subsystem(chan, "example-subsystem")
    end

    test "returns an error if the initialization times out", %{chan: chan} do
      expect(@core, :subsystem, fn _, _, _, _ -> {:error, :timeout} end)
      assert {:error, :timeout} == subsystem(chan, "example-subsystem")
    end
  end

  describe "close/1" do
    test "closes the channel", %{chan: chan} do
      expect(@core, :close, fn connection_ref, channel_id ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        :ok
      end)

      assert close(chan) == :ok
    end
  end

  describe "exec/3" do
    test "executes a command (binary) over a channel", %{chan: chan} do
      expect(@core, :exec, fn connection_ref, channel_id, command, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert command == 'cmd arg1 arg2'
        assert timeout == :infinity
        :success
      end)

      assert exec(chan, "cmd arg1 arg2") == :success
    end

    test "executes a command (charlist) over a channel", %{chan: chan} do
      expect(@core, :exec, fn connection_ref, channel_id, command, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert command == 'cmd arg1 arg2'
        assert timeout == :infinity
        :success
      end)

      assert exec(chan, 'cmd arg1 arg2') == :success
    end

    test "executes a command with a specific timeout", %{chan: chan} do
      expect(@core, :exec, fn _, _, _, timeout ->
        assert timeout == 4000
        {:ok, 0}
      end)

      {:ok, _} = exec(chan, "cmd", 4000)
    end

    test "executes a failing command", %{chan: chan} do
      expect(@core, :exec, fn _, _, _, _ -> :failure end)
      assert exec(chan, "cmd") == :failure
    end

    test "returns an error if command cannot be executed", %{chan: chan} do
      expect(@core, :exec, fn _, _, _, _ -> {:error, :closed} end)
      assert exec(chan, "cmd") == {:error, :closed}
    end
  end

  describe "ptty/4" do
    test "allocates ptty", %{chan: chan} do
      expect(@core, :ptty_alloc, fn connection_ref, channel_id, options, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert options == []
        assert timeout == :infinity
        :success
      end)

      assert ptty(chan) == :success
    end
  end

  describe "send/4" do
    test "send binary data across channel", %{chan: chan} do
      expect(@core, :send, sends(chan, 0, "binary data", :infinity, :ok))
      assert Channel.send(chan, "binary data") == :ok
    end

    test "sends charlist data across channel", %{chan: chan} do
      expect(@core, :send, sends(chan, 0, 'charlist data', :infinity, :ok))
      assert Channel.send(chan, 'charlist data') == :ok
    end

    test "sends stream data across channel", %{chan: chan} do
      data = 0..2 |> Stream.map(&Integer.to_string/1)

      @core
      |> expect(:send, sends(chan, 0, "0", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "1", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "2", :infinity, :ok))

      assert Channel.send(chan, data) == :ok
    end

    test "returns an error streaming data fails", %{chan: chan} do
      data = 0..2 |> Stream.map(&Integer.to_string/1)

      @core
      |> expect(:send, sends(chan, 0, "0", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "1", :infinity, {:error, :timeout}))

      assert Channel.send(chan, data) == {:error, :timeout}
    end

    test "returns an error when channel not open", %{chan: chan} do
      expect(@core, :send, fn _, _, _, _, _ -> {:error, :closed} end)
      assert Channel.send(chan, "data") == {:error, :closed}
    end

    test "returns an error when channel times out", %{chan: chan} do
      expect(@core, :send, fn _, _, _, _, _ -> {:error, :timeout} end)
      assert Channel.send(chan, "data") == {:error, :timeout}
    end
  end

  describe "eof/1" do
    test "sends EOF to open channel", %{chan: chan} do
      expect(@core, :send_eof, fn connection_ref, channel_id ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        :ok
      end)

      assert eof(chan) == :ok
    end

    test "returns an error when channel not open", %{chan: chan} do
      expect(@core, :send_eof, fn _, _ -> {:error, :closed} end)
      assert eof(chan) == {:error, :closed}
    end
  end

  describe "recv/2" do
    test "times out when no message is received within threshold", %{chan: chan} do
      assert recv(chan, 1) == {:error, :timeout}
    end

    test "returns received message", %{conn: conn, chan: chan} do
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id}})
      assert recv(chan, 0) == {:ok, {:msg, chan}}
    end

    test "ignores messages for other channels", %{conn: conn, chan: chan} do
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id + 1}})
      assert recv(chan, 0) == {:error, :timeout}
    end
  end

  describe "flush/2" do
    test "flushes when no messages in channel", %{chan: chan} do
      assert flush(chan, 0) == :ok
      assert messages(self()) == []
    end

    test "flushes multiple messages in channel", %{conn: conn, chan: chan} do
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg1, chan.id}})
      Kernel.send(self(), {:ssh_cm, conn.ref, {:msg2, chan.id}})
      assert flush(chan, 0) == :ok
      assert messages(self()) == []
    end

    test "keeps messages for other channels", %{conn: conn, chan: chan} do
      msg = {:ssh_cm, conn.ref, {:msg, chan.id + 1}}
      Kernel.send(self(), msg)
      assert flush(chan, 0) == :ok
      assert messages(self()) == [msg]
    end
  end

  describe "adjust/2" do
    test "returns an error when the window size is a string", %{chan: chan} do
      assert_raise FunctionClauseError, ~r/no function clause matching/, fn ->
        adjust(chan, "1024")
      end
    end

    test "adjusts the window size", %{chan: chan} do
      expect(@core, :adjust_window, fn connection_ref, channel_id, size ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert size == 4096
        :ok
      end)

      assert adjust(chan, 4096) == :ok
    end
  end

  defp sends(chan, expected_type, expected_data, expected_timeout, res) do
    fn connection_ref, channel_id, type, data, timeout ->
      assert connection_ref == chan.connection.ref
      assert channel_id == chan.id
      assert type == expected_type
      assert data == expected_data
      assert timeout == expected_timeout
      res
    end
  end

  defp messages(pid) do
    pid
    |> Process.info(:messages)
    |> elem(1)
  end
end
