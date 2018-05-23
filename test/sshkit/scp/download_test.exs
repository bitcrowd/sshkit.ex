defmodule SSHKit.SCP.DownloadTest do
  use ExUnit.Case, async: true
  import Mox

  alias SSHKit.AssertionHelpers
  alias SSHKit.SCP.Download
  alias SSHKit.SSHMock

  @local AssertionHelpers.create_local_tmp_path()
  @remote "/home/test/code"

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
    setup do
      {:ok, conn: %SSHKit.SSH.Connection{}}
    end

    test "uses the provided timeout option", %{conn: conn} do
      download = Download.new(@remote, @local, timeout: 55, ssh: SSHMock)
      SSHMock |> expect(:run, fn(_, _, timeout: timeout, acc: _, fun: _) ->
        assert timeout == 55
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, conn)
    end

    test "performs a download", %{conn: conn} do
      download = Download.new(@remote, @local, ssh: SSHMock)
      SSHMock |> expect(:run, fn(connection, command, timeout: timeout, acc: {:cont, <<0>>, state}, fun: handler) ->
        assert connection == conn
        assert command == "scp -f /home/test/code"
        assert timeout == :infinity
        assert state == download.state
        assert handler == download.handler
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, conn)
    end

    test "sets the right options", %{conn: conn} do
      download = Download.new(@remote, @local, preserve: true, recursive: true, ssh: SSHMock)
      SSHMock |> expect(:run, fn(_, command, timeout: _, acc: {:cont, <<0>>, _}, fun: _) ->
        assert command == "scp -f -p -r /home/test/code"
        {:ok, :success}
      end)
      assert {:ok, :success} = Download.exec(download, conn)
    end
  end

  describe "exec handler with default options and local pointing to an actual directory" do
    setup do
      channel = %SSHKit.SSH.Channel{}
      local = AssertionHelpers.create_local_tmp_path()
      :ok = File.mkdir_p(local)
      %Download{handler: handler, state: state} = Download.new(@remote, local)

      {:ok, local: local, handler: handler, state: state, channel: channel}
    end

    test "halts when receiving an invalid SCP directive", %{handler: handler, state: state, channel: channel} do
      msg = {:data, channel, 0, "XXX\n"}
      assert {:halt, {:error, "Invalid SCP directive received: XXX\n"}} == handler.(msg, state)
    end

    test "downloads a single file from the remote", %{handler: handler, state: state, local: local, channel: channel} do
      file_path = Path.join(local, "testfile.txt")
      refute File.exists?(file_path)

      msg = {:data, channel, 0, "C0600 4 testfile.txt\n"}
      {:cont, <<0>>, state1} = handler.(msg, state)
      assert {:read, ^file_path, [], _, ""} = state1

      msg1 = {:data, channel, 0, "hello\n"}
      {:cont, state2} = handler.(msg1, state1)
      assert {:read, ^file_path, [], _, ""} = state2

      assert File.exists?(file_path)
      assert %File.Stat{mode: 33188, size: 4, type: :regular} = File.stat!(file_path)
    end
  end

  describe "exec handler with preserve and recursive option" do
    setup do
      channel = %SSHKit.SSH.Channel{}
      local = AssertionHelpers.create_local_tmp_path()
      :ok = File.mkdir_p(local)
      %Download{handler: handler, state: state} = Download.new(@remote, local, preserve: true, recursive: true)

      {:ok, local: local, handler: handler, state: state, channel: channel}
    end

    # test "preserves a file's timestamps", %{handler: handler, state: state, local: local, channel: channel} do
    #   file_name = "testfile2.txt"
    #   file_path = Path.join(local, file_name)
    #   refute File.exists?(file_path)
    #
    #   msg = {:data, channel, 0, "T1183833773 0 1183833956 0\n"}
    #   {:cont, <<0>>, state1} = handler.(msg, state)
    #   assert {:next, ^local, [], _, ""} = state1
    #
    #   msg1 = {:data, channel, 0, "C0600 4 #{file_name}\n"}
    #   {:cont, <<0>>, state2} = handler.(msg1, state1)
    #   assert {:read, ^file_path, [], _, ""} = state2
    #
    #   msg2 = {:data, channel, 0, "hello\n"}
    #   {:cont, state3} = handler.(msg2, state2)
    #   assert {:read, ^file_path, [], _, ""} = state3
    #
    #   assert File.exists?(file_path)
    #   assert %File.Stat{atime: 1183833956, mtime: 1183833773} = File.stat!(file_path)
    # end

    # test "downloads directories recursively and preserves timestamps", %{handler: handler, state: state, local: local, channel: channel} do
    #   directory_name = "foodir"
    #   directory_path = Path.join(local, directory_name)
    #   refute File.exists?(directory_path)
    #
    #   msg = {:data, channel, 0, "T1183832947 0 1183833956 0\n"}
    #   {:cont, <<0>>, state1} = handler.(msg, state)
    #   assert {:next, ^local, [], %{atime: 1183833956, mtime: 1183832947}, ""} = state1
    #
    #   msg = {:data, channel, 0, "D0700 0 #{directory_name}\n"}
    #   {:cont, <<0>>, state1} = handler.(msg, state)
    #   assert {:next, ^directory_path, [%{mode: 448}], %{}, ""} = state1
    #
    #   msg1 = {:data, channel, 0, "E\n"}
    #   {:cont, <<0>>, state2} = handler.(msg1, state1)
    #   assert {:next, ^local, [], %{}, ""} = state2
    #
    #   assert File.exists?(directory_path)
    #   assert %File.Stat{type: :directory} = File.stat!(directory_path)
    # end
  end
end
