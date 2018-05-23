defmodule SSHKit.SSH.ChannelTest do
  use ExUnit.Case, async: true
  import Mox

  import SSHKit.SSH.Channel

  alias SSHKit.SSH.Channel
  alias SSHKit.SSH.Connection

  setup do
    Mox.verify_on_exit!()

    conn = %Connection{ref: :test_connection, impl: Connection.ImplMock}
    chan = %Channel{connection: conn, type: :session, id: 1, impl: Channel.ImplMock}

    {:ok, conn: conn, chan: chan, impl: Channel.ImplMock}
  end

  describe "open/2" do
    test "opens a channel on a connection", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn connection_ref, ini_window_size, max_packet_size, timeout ->
        assert connection_ref == conn.ref
        assert ini_window_size == 128 * 1024
        assert max_packet_size == 32 * 1024
        assert timeout == :infinity
        {:ok, 0}
      end)

      {:ok, chan} = open(conn, impl: impl)

      assert chan == %Channel{
               connection: conn,
               type: :session,
               id: 0,
               impl: impl
             }
    end

    test "opens a channel with a specific timeout", %{conn: conn, impl: impl} do
      impl
      |> expect(:session_channel, fn _, _, _, timeout ->
        assert timeout == 3000
        {:ok, 0}
      end)

      {:ok, _} = open(conn, timeout: 3000, impl: impl)
    end

    test "returns an error if channel cannot be opened", %{conn: conn, impl: impl} do
      impl |> expect(:session_channel, fn _, _, _, _ -> {:error, :timeout} end)
      assert open(conn, impl: impl) == {:error, :timeout}
    end
  end

  describe "close/1" do
    test "closes the channel", %{chan: chan, impl: impl} do
      impl
      |> expect(:close, fn connection_ref, channel_id ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        :ok
      end)

      assert close(chan) == :ok
    end
  end

  describe "exec/3" do
    test "executes a command (binary) over a channel", %{chan: chan, impl: impl} do
      impl
      |> expect(:exec, fn connection_ref, channel_id, command, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert command == 'cmd arg1 arg2'
        assert timeout == :infinity
        :success
      end)

      assert exec(chan, "cmd arg1 arg2") == :success
    end

    test "executes a command (charlist) over a channel", %{chan: chan, impl: impl} do
      impl
      |> expect(:exec, fn connection_ref, channel_id, command, timeout ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert command == 'cmd arg1 arg2'
        assert timeout == :infinity
        :success
      end)

      assert exec(chan, 'cmd arg1 arg2') == :success
    end

    test "executes a command with a specific timeout", %{chan: chan, impl: impl} do
      impl
      |> expect(:exec, fn _, _, _, timeout ->
        assert timeout == 4000
        {:ok, 0}
      end)

      {:ok, _} = exec(chan, "cmd", 4000)
    end

    test "executes a failing command", %{chan: chan, impl: impl} do
      impl |> expect(:exec, fn _, _, _, _ -> :failure end)
      assert exec(chan, "cmd") == :failure
    end

    test "returns an error if command cannot be executed", %{chan: chan, impl: impl} do
      impl |> expect(:exec, fn _, _, _, _ -> {:error, :closed} end)
      assert exec(chan, "cmd") == {:error, :closed}
    end
  end

  describe "send/4" do
    test "send binary data across channel", %{chan: chan, impl: impl} do
      impl |> expect(:send, sends(chan, 0, "binary data", :infinity, :ok))
      assert Channel.send(chan, "binary data") == :ok
    end

    test "sends charlist data across channel", %{chan: chan, impl: impl} do
      impl |> expect(:send, sends(chan, 0, 'charlist data', :infinity, :ok))
      assert Channel.send(chan, 'charlist data') == :ok
    end

    test "sends stream data across channel", %{chan: chan, impl: impl} do
      data = 0..2 |> Stream.map(&Integer.to_string/1)

      impl
      |> expect(:send, sends(chan, 0, "0", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "1", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "2", :infinity, :ok))

      assert Channel.send(chan, data) == :ok
    end

    test "returns an error streaming data fails", %{chan: chan, impl: impl} do
      data = 0..2 |> Stream.map(&Integer.to_string/1)

      impl
      |> expect(:send, sends(chan, 0, "0", :infinity, :ok))
      |> expect(:send, sends(chan, 0, "1", :infinity, {:error, :timeout}))

      assert Channel.send(chan, data) == {:error, :timeout}
    end

    test "returns an error when channel not open", %{chan: chan, impl: impl} do
      impl |> expect(:send, fn _, _, _, _, _ -> {:error, :closed} end)
      assert Channel.send(chan, "data") == {:error, :closed}
    end

    test "returns an error when channel times out", %{chan: chan, impl: impl} do
      impl |> expect(:send, fn _, _, _, _, _ -> {:error, :timeout} end)
      assert Channel.send(chan, "data") == {:error, :timeout}
    end
  end

  describe "eof/1" do
    test "sends EOF to open channel", %{chan: chan, impl: impl} do
      impl
      |> expect(:send_eof, fn connection_ref, channel_id ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        :ok
      end)

      assert eof(chan) == :ok
    end

    test "returns an error when channel not open", %{chan: chan, impl: impl} do
      impl |> expect(:send_eof, fn _, _ -> {:error, :closed} end)
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

    test "adjusts the window size", %{chan: chan, impl: impl} do
      impl
      |> expect(:adjust_window, fn connection_ref, channel_id, size ->
        assert connection_ref == chan.connection.ref
        assert channel_id == chan.id
        assert size == 4096
        :ok
      end)

      assert adjust(chan, 4096) == :ok
    end
  end

  describe "loop/4" do
    test "loops over channel messages until channel is closed", %{conn: conn, chan: chan} do
      Enum.each(0..2, &Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id, &1}}))
      Kernel.send(self(), {:ssh_cm, conn.ref, {:closed, chan.id}})
      assert Enum.count(messages(self())) == 4

      fun = fn
        {:msg, _, index}, _ -> {:cont, index}
        {:closed, _}, acc -> {:cont, acc}
      end

      assert loop(chan, 0, {:cont, -1}, fun) == {:done, 2}
      assert messages(self()) == []
    end

    test "allows sending messages to the remote", %{conn: conn, chan: chan, impl: impl} do
      impl
      |> expect(:send_eof, fn _, _ -> :ok end)
      |> expect(:send, sends(chan, 0, "plain", 200, :ok))
      |> expect(:send, sends(chan, 0, "normal", 200, :ok))
      |> expect(:send, sends(chan, 1, "error", 200, :ok))

      Enum.each(0..4, &Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id, &1}}))
      Kernel.send(self(), {:ssh_cm, conn.ref, {:closed, chan.id}})

      msgs = [nil, :eof, "plain", {0, "normal"}, {1, "error"}]

      fun = fn
        {:msg, _, index}, _ -> {:cont, Enum.at(msgs, index), index}
        {:closed, _}, acc -> {:cont, acc}
      end

      assert loop(chan, 200, {:cont, -1}, fun) == {:done, 4}
      assert messages(self()) == []
    end

    test "allows suspending the loop", %{conn: conn, chan: chan} do
      Enum.each(0..1, &Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id, &1}}))
      Kernel.send(self(), {:ssh_cm, conn.ref, {:closed, chan.id}})

      fun = fn
        {:msg, _, _}, acc when acc < 5 -> {:suspend, acc + 1}
        {:msg, _, _}, acc -> {:cont, acc * 3}
        {:closed, _}, acc -> {:cont, acc}
      end

      {:suspended, 1, continue} = loop(chan, 0, {:cont, 0}, fun)

      assert continue.({:cont, 5}) == {:done, 15}
      assert messages(self()) == []
    end

    test "allows halting the loop", %{conn: conn, chan: chan, impl: impl} do
      impl |> expect(:close, fn _, _ -> :ok end)

      Enum.each(0..5, &Kernel.send(self(), {:ssh_cm, conn.ref, {:msg, chan.id, &1}}))

      fun = fn
        _, acc when acc < 2 -> {:cont, acc + 1}
        _, acc -> {:halt, acc}
      end

      assert loop(chan, 0, {:cont, 0}, fun) == {:halted, 2}
      # remaining messages flushed
      assert messages(self()) == []
    end

    test "returns an error if next message is not received in time", %{chan: chan, impl: impl} do
      impl |> expect(:close, fn _, _ -> :ok end)
      res = loop(chan, 0, {:cont, []}, &[&1 | &2])
      assert res == {:halted, {:error, :timeout}}
    end

    test "returns an error if message sending fails", %{chan: chan, impl: impl} do
      impl
      |> expect(:send, sends(chan, 0, "data", 100, {:error, :timeout}))
      |> expect(:close, fn _, _ -> :ok end)

      res = loop(chan, 100, {:cont, "data", []}, &[&1 | &2])

      assert res == {:halted, {:error, :timeout}}
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
