defmodule SSHKit.SCP.UploadTest do
  use ExUnit.Case, async: true
  import Mox

  alias SSHKit.SCP.Upload
  alias SSHKit.SSHMock

  @local "test/fixtures"
  @abslocal @local |> Path.expand()
  @remote "/home/test/code"

  describe "new/3" do
    test "returns a new upload struct" do
      upload = Upload.new(@local, @remote)
      assert %Upload{local: @abslocal, remote: @remote} = upload
    end

    test "returns a new upload struct with options" do
      options = [recursive: true]
      upload = Upload.new(@local, @remote, options)
      assert %Upload{options: ^options} = upload
    end

    test "upload struct has initial state" do
      %Upload{state: state} = Upload.new(@local, @remote)
      base_directory = @abslocal |> Path.dirname()
      assert state == {:next, base_directory, [["fixtures"]], []}
    end

    test "upload struct has a handler function" do
      %Upload{handler: handler} = Upload.new(@local, @remote)
      assert is_function(handler)
    end
  end

  describe "exec/2" do
    setup do
      {:ok, conn: %SSHKit.SSH.Connection{}}
    end

    test "returns error when trying to upload a directory non-recursively", %{conn: conn} do
      upload = Upload.new(@local, @remote, recursive: false)
      assert {:error, _msg} = Upload.exec(upload, conn)
    end

    test "uses the provided timeout option", %{conn: conn} do
      upload = Upload.new(@local, @remote, recursive: true, timeout: 55, ssh: SSHMock)
      SSHMock |> expect(:run, fn (_, _, timeout: timeout, acc: {:cont, _}, fun: _) ->
        assert timeout == 55
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, conn)
    end

    test "performs an upload", %{conn: conn} do
      upload = Upload.new(@local, @remote, recursive: true, ssh: SSHMock)
      SSHMock |> expect(:run, fn (connection, command, timeout: timeout, acc: {:cont, state}, fun: handler) ->
        assert connection == conn
        assert command == SSHKit.SCP.Command.build(:upload, upload.remote, upload.options)
        assert timeout == :infinity
        assert state == upload.state
        assert handler == upload.handler
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, conn)
    end
  end

  describe "exec handler" do
    setup do
      channel = %SSHKit.SSH.Channel{}
      ack_message = {:data, channel, 0, <<0>>}
      {:ok, upload: Upload.new(@local, @remote), ack: ack_message, channel: channel}
    end

    test "recurses into directories", %{upload: upload, ack: ack} do
      %Upload{handler: handler, state: {:next, cwd, [["fixtures"]], []} = state} = upload
      next_path = Path.join(cwd, "fixtures")

      assert {:cont, 'D0755 0 fixtures\n', {:next, ^next_path, [["local.txt", "local_dir"], []], []}} = handler.(ack, state)
    end

    test "create files in the current directory", %{upload: %Upload{handler: handler}, ack: ack} do
      state = {:next, @abslocal, [["local.txt", "local_dir"], []], []}
      assert {:cont, 'C0644 51 local.txt\n', {:write, "local.txt", %File.Stat{}, @abslocal, [["local_dir"], []], []}} = handler.(ack, state)
    end

    test "writes files in the current directory", %{upload: %Upload{handler: handler}, ack: ack} do
      cwd = @abslocal |> Path.join("local_dir")
      state = {:write, "other.txt", %File.Stat{}, cwd, [[], []], []}
      fs = File.stream!(Path.join(cwd, "other.txt"), [], 16_384)
      write_state = {:cont, Stream.concat(fs, [<<0>>]), {:next, cwd, [[], []], []}}

      assert write_state == handler.(ack, state)
    end

    test "moves upwards in the directory hierachy", %{upload: %Upload{handler: handler}, ack: ack} do
      cwd = @abslocal |> Path.join("local_dir")
      state = {:next, cwd, [[], []], []}

      assert {:cont, 'E\n', {:next, @abslocal, [[]], []}} = handler.(ack, state)
    end

    test "finalizes the upload", %{upload: %Upload{handler: handler}, ack: ack, channel: channel} do
      state = {:next, @abslocal, [[]], []}

      assert {:cont, :eof, done_state} = handler.(ack, state)
      assert done_state == {:done, nil, []}

      exit_msg = {:exit_status, channel, 0}
      assert {:cont, exit_state} = handler.(exit_msg, done_state)
      assert exit_state == {:done, 0, []}

      eof_msg = {:eof, channel}
      assert {:cont, eof_state} = handler.(eof_msg, exit_state)
      assert eof_state == {:done, 0, []}

      closed_msg = {:closed, channel}
      assert {:cont, :ok} == handler.(closed_msg, eof_state)
    end

    test "aggregates warnings in the state and skips to the next file", %{upload: %Upload{handler: handler}, channel: channel} do
      warning = "scp: /some/nonexistent/destination: No such file or directory"
      state = {:next, @abslocal, [["local.txt", "local_dir"], []], []}

      msg1 = {:data, channel, 0, <<1, "scp: ">>}
      state1 = {:warning, state, "scp: "}
      assert {:cont, state1} == handler.(msg1, state)

      msg2 = {:data, channel, 0, <<"/some/nonexistent/destination: ">>}
      state2 = {:warning, state, "scp: /some/nonexistent/destination: "}
      assert {:cont, state2} == handler.(msg2, state1)

      msg3 = {:data, channel, 0, <<"No such file or directory\n">>}
      assert {:cont, 'D0755 0 local_dir\n', {:next, Path.join(@abslocal, "local_dir"), [["other.txt"], [], []], [warning]}} == handler.(msg3, state2)
    end

    test "aggregates connection errors in the state and halts", %{upload: %Upload{handler: handler, state: state}, channel: channel} do
      error_msg = "error part 1 error part 2 error part 3"

      msg1 = {:data, channel, 0, <<2, "error part 1 ">>}
      state1 = {:fatal, state, "error part 1 "}
      assert {:cont, state1} == handler.(msg1, state)

      msg2 = {:data, channel, 0, <<"error part 2 ">>}
      state2 = {:fatal, state, "error part 1 error part 2 "}
      assert {:cont, state2} == handler.(msg2, state1)

      msg3 = {:data, channel, 0, <<"error part 3\n">>}
      assert {:halt, {:error, error_msg}} == handler.(msg3, state2)
    end
  end
end
