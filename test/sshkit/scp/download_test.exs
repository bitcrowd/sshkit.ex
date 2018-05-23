defmodule SSHKit.SCP.DownloadTest do
  use ExUnit.Case, async: true
  import Mox

  alias SSHKit.AssertionHelpers
  alias SSHKit.SCP.Download
  alias SSHKit.SSHMock

  @local AssertionHelpers.create_local_tmp_path()
  @remote "/home/test/code"
  @conn %SSHKit.SSH.Connection{}
  @chan %SSHKit.SSH.Channel{}

  describe "new/3" do
    test "returns a new download struct with an initial state" do
      download = Download.new(@remote, @local)
      state = {:next, @local, [], %{}, <<>>}
      assert %Download{remote: @remote, local: @local, state: ^state} = download
    end

    test "returns a new download struct with options" do
      options = [recursive: true]
      download = Download.new(@remote, @local, options)
      assert %Download{options: ^options} = download
    end

    test "download struct has a handler function" do
      %Download{handler: handler} = Download.new(@remote, @local)
      assert is_function(handler)
    end
  end

  describe "exec/2" do
    test "uses the provided timeout option" do
      download = Download.new(@remote, @local, timeout: 55, ssh: SSHMock)
      SSHMock |> expect(:run, fn(_, _, timeout: timeout, acc: _, fun: _) ->
        assert timeout == 55
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, @conn)
    end

    test "performs a download" do
      download = Download.new(@remote, @local, ssh: SSHMock)
      SSHMock |> expect(:run, fn(connection, command, timeout: timeout, acc: {:cont, <<0>>, state}, fun: handler) ->
        assert connection == @conn
        assert command == "scp -f /home/test/code"
        assert timeout == :infinity
        assert state == download.state
        assert handler == download.handler
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, @conn)
    end

    test "sets the right options" do
      download = Download.new(@remote, @local, preserve: true, recursive: true, ssh: SSHMock)
      SSHMock |> expect(:run, fn(_, command, timeout: _, acc: {:cont, <<0>>, _}, fun: _) ->
        assert command == "scp -f -p -r /home/test/code"
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, @conn)
    end
  end

  describe "exec handler with default options" do
    setup do
      local = AssertionHelpers.create_local_tmp_path()
      %Download{handler: handler, state: state} = Download.new(@remote, local)
      {:ok, local: local, handler: handler, state: state}
    end

    test "halts when receiving an invalid SCP directive", %{handler: handler, state: state} do
      msg = {:data, @chan, 0, "XXX\n"}
      assert {:halt, {:error, "Invalid SCP directive received: XXX\n"}} == handler.(msg, state)
    end

    test "downloads a single file from the remote", %{handler: handler, state: state, local: local} do
      msg = {:data, @chan, 0, "C0600 4 test\n"}
      {:cont, <<0>>, state1} = handler.(msg, state)
      assert {:read, ^local, [], %{device: _, length: 4, mode: 384, written: 0}, ""} = state1

      msg1 = {:data, @chan, 0, "hello\n"}
      {:cont, state2} = handler.(msg1, state1)
      assert {:read, ^local, [], %{device: _, length: 4, mode: 384, written: 4}, ""} = state2
    end
  end

  describe "exec handler with preserve and recursive option" do
    setup do
      local = AssertionHelpers.create_local_tmp_path()
      %Download{handler: handler, state: state} = Download.new(@remote, local, preserve: true, recursive: true)
      {:ok, local: local, handler: handler, state: state}
    end

    test "preserves a file's timestamps", %{handler: handler, state: state, local: local} do
      msg = {:data, @chan, 0, "T1183833773 0 1183833956 0\n"}
      {:cont, <<0>>, state1} = handler.(msg, state)
      assert {:next, ^local, [], %{atime: 1183833956, mtime: 1183833773}, ""} = state1

      msg1 = {:data, @chan, 0, "C0600 4 test2\n"}
      {:cont, <<0>>, state2} = handler.(msg1, state1)
      assert {:read, ^local, [], %{atime: 1183833956, device: _, length: 4, mode: 384, written: 0, mtime: 1183833773}, ""} = state2

      msg2 = {:data, @chan, 0, "hello\n"}
      {:cont, state3} = handler.(msg2, state2)
      assert {:read, ^local, [], %{device: _, length: 4, mode: 384, written: 4, atime: 1183833956, mtime: 1183833773}, ""} = state3
    end
  end

  describe "exec handler with recursive option and without preserve option" do
    setup do
      local = AssertionHelpers.create_local_tmp_path()
      %Download{handler: handler, state: state} = Download.new(@remote, local, recursive: true)
      {:ok, local: local, handler: handler, state: state}
    end

    test "downloads directories recursively and preserves timestamps", %{handler: handler, state: state, local: local} do
      parent_directory = Path.dirname(local)

      msg = {:data, @chan, 0, "T1183833773 0 1183833956 0\n"}
      {:cont, <<0>>, state1} = handler.(msg, state)
      assert {:next, ^local, [], %{atime: 1183833956, mtime: 1183833773}, ""} = state1

      msg = {:data, @chan, 0, "D0700 0 foodir\n"}
      {:cont, <<0>>, state1} = handler.(msg, state)
      assert {:next, ^local, [%{mode: 448}], %{}, ""} = state1

      msg1 = {:data, @chan, 0, "E\n"}
      {:cont, <<0>>, state2} = handler.(msg1, state1)
      assert {:next, ^parent_directory, [], %{}, ""} = state2
    end
  end
end
