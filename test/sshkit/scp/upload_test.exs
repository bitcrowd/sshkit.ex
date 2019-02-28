defmodule SSHKit.SCP.UploadTest do
  use ExUnit.Case, async: true

  import Mox

  alias SSHKit.SCP.Command
  alias SSHKit.SCP.Upload
  alias SSHKit.SSHMock

  @source "test/fixtures/local_dir"
  @target "/home/test/code"

  describe "init/2" do
    test "returns a new upload struct" do
      upload = Upload.init(@source, @target)
      assert %Upload{source: @source target: @target} = upload
    end
  end

  describe "init/3" do
    test "returns a new upload struct with options" do
      upload = Upload.init(@source, @target, [recursive: true])
      assert %Upload{source: @source target: @target} = upload
      assert %Upload{options: [recursive: true]} = upload
    end
  end

  describe "start/2" do
    setup do
      {:ok, conn: %SSHKit.SSH.Connection{}}
    end

    test "initializes the upload state" do
      %Upload{state: state} = Upload.init(@source, @target)
      cwd = @source |> Path.expand() |> Path.dirname()
      assert state == {:next, cwd, [["local_dir"]], []}
    end

    test "allows modifying the executed scp command", %{conn: conn} do
      upload = Upload.init(@source, @target, map_cmd: &"(( #{&1} ))", ssh: SSHMock, recursive: true)

      SSHMock |> expect(:run, fn (_, command, _) ->
        assert command == "(( #{Command.build(:upload, upload.target, recursive: true)} ))"
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, conn)
    end

    test "returns error when trying to upload a directory non-recursively", %{conn: conn} do
      upload = Upload.init(@source, @target, recursive: false)
      assert {:error, _msg} = Upload.exec(upload, conn)
    end

    test "uses the provided timeout option", %{conn: conn} do
      upload = Upload.init(@source, @target, recursive: true, timeout: 55, ssh: SSHMock)

      SSHMock |> expect(:run, fn (_, _, timeout: timeout, acc: {:cont, _}, fun: _) ->
        assert timeout == 55
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, conn)
    end

    test "performs an upload", %{conn: conn} do
      upload = Upload.init(@source, @target, recursive: true, ssh: SSHMock)

      SSHMock |> expect(:run, fn (connection, command, timeout: timeout, acc: {:cont, state}, fun: handler) ->
        assert connection == conn
        assert command == SSHKit.SCP.Command.build(:upload, upload.target, upload.options)
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
      {:ok, upload: Upload.init(@source, @target), ack: ack_message, channel: channel}
    end

    test "recurses into directories", %{upload: upload, ack: ack} do
      %Upload{handler: handler, state: {:next, cwd, [["local_dir"]], []} = state} = upload
      next_path = Path.join(cwd, "local_dir")

      assert {:cont, 'D0755 0 local_dir\n', {:next, ^next_path, [["other.txt"], []], []}} = handler.(ack, state)
    end

    test "create files in the current directory", %{upload: %Upload{handler: handler}, ack: ack} do
      source_expanded = @source |> Path.expand()
      state = {:next, source_expanded, [["other.txt"], []], []}
      assert {:cont, 'C0644 61 other.txt\n', {:write, "other.txt", %File.Stat{}, ^source_expanded, [[], []], []}} = handler.(ack, state)
    end

    test "writes files in the current directory", %{upload: %Upload{handler: handler}, ack: ack} do
      source_expanded = @source |> Path.expand() |> Path.join("local_dir")
      state = {:write, "other.txt", %File.Stat{}, source_expanded, [[], []], []}
      fs = File.stream!(Path.join(source_expanded, "other.txt"), [], 16_384)
      write_state = {:cont, Stream.concat(fs, [<<0>>]), {:next, source_expanded, [[], []], []}}

      assert write_state == handler.(ack, state)
    end

    test "moves upwards in the directory hierachy", %{upload: %Upload{handler: handler}, ack: ack} do
      source_dir = @source |> Path.expand() |> Path.join("local_dir")
      source_expanded = @source |> Path.expand()
      state = {:next, source_dir, [[], []], []}

      assert {:cont, 'E\n', {:next, ^source_expanded, [[]], []}} = handler.(ack, state)
    end

    test "finalizes the upload", %{upload: %Upload{handler: handler}, ack: ack, channel: channel} do
      source_expanded = @source |> Path.expand()
      state = {:next, source_expanded, [[]], []}

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

    test "aggregates warnings in the state", %{upload: %Upload{handler: handler, state: state}, channel: channel} do
      error_msg = "error part 1 error part 2 error part 3"
      {name, cwd, stack, _errs} = state

      msg1 = {:data, channel, 0, <<1, "error part 1 ">>}
      state1 = {:warning, state, "error part 1 "}
      assert {:cont, state1} == handler.(msg1, state)

      msg2 = {:data, channel, 0, <<"error part 2 ">>}
      state2 = {:warning, state, "error part 1 error part 2 "}
      assert {:cont, state2} == handler.(msg2, state1)

      msg3 = {:data, channel, 0, <<"error part 3\n">>}
      assert {:cont, {name, cwd, stack, [error_msg]}} == handler.(msg3, state2)
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
