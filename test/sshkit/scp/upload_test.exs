defmodule SSHKit.SCP.UploadTest do
  use ExUnit.Case, async: true
  import Mox

  alias SSHKit.SCP.Upload
  alias SSHKit.SSHMock

  @local "test/fixtures/local_dir"
  @remote "/home/test/code"
  @conn %SSHKit.SSH.Connection{}
  @chan %SSHKit.SSH.Channel{}

  describe "new/3" do
    test "returns a new upload struct" do
      upload = Upload.new(@local, @remote)
      local_expanded = @local |> Path.expand()
      assert %Upload{local: ^local_expanded, remote: @remote} = upload
    end

    test "returns a new upload struct with options" do
      options = [recursive: true]
      upload = Upload.new(@local, @remote, options)
      assert %Upload{options: ^options} = upload
    end

    test "upload struct has initial state" do
      %Upload{state: state} = Upload.new(@local, @remote)
      current_directory = @local |> Path.expand() |> Path.dirname()
      assert state == {:next, current_directory, [["local_dir"]], []}
    end

    test "upload struct has a handler function" do
      %Upload{handler: handler} = Upload.new(@local, @remote)
      assert is_function(handler)
    end
  end

  describe "exec/2" do
    test "returns error when trying to upload a directory non-recursively" do
      upload = Upload.new(@local, @remote, recursive: false)
      assert {:error, _msg} = Upload.exec(upload, @conn)
    end

    test "uses the provided timeout option" do
      upload = Upload.new(@local, @remote, recursive: true, timeout: 55, ssh: SSHMock)
      SSHMock |> expect(:run, fn(_, _, timeout: timeout, acc: {:cont, _}, fun: _) ->
        assert timeout == 55
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, @conn)
    end

    test "performs an upload" do
      upload = Upload.new(@local, @remote, recursive: true, ssh: SSHMock)
      SSHMock |> expect(:run, fn(connection, command, timeout: timeout, acc: {:cont, state}, fun: handler) ->
        assert connection == @conn
        assert command == SSHKit.SCP.Command.build(:upload, upload.remote, upload.options)
        assert timeout == :infinity
        assert state == upload.state
        assert handler == upload.handler
        {:ok, :success}
      end)

      assert {:ok, :success} = Upload.exec(upload, @conn)
    end
  end

  describe "exec handler" do
    setup do
      {:ok, upload: Upload.new(@local, @remote), msg: {:data, @chan, 0, <<0>>}}
    end

    test "recurses into directories", %{upload: upload, msg: msg} do
      %Upload{handler: handler, state: {:next, cwd, [["local_dir"]], []} = state} = upload
      next_path = Path.join(cwd, "local_dir")

      assert {:cont, 'D0755 0 local_dir\n', {:next, ^next_path, [["other.txt"], []], []}} = handler.(msg, state)
    end

    test "create files in the current directory", %{upload: %Upload{handler: handler}, msg: msg} do
      local_expanded = @local |> Path.expand()
      state = {:next, local_expanded, [["other.txt"], []], []}


      assert {:cont, 'C0644 61 other.txt\n', {:write, "other.txt", %File.Stat{}, ^local_expanded, [[], []], []}} = handler.(msg, state)
    end

    test "writes files in the current directory", %{upload: %Upload{handler: handler}, msg: msg} do
      local_expanded = @local |> Path.expand() |> Path.join("local_dir")
      state = {:write, "other.txt", %File.Stat{}, local_expanded, [[], []], []}
      fs = File.stream!(Path.join(local_expanded, "other.txt"), [], 16_384)
      write_state = {:cont, Stream.concat(fs, [<<0>>]), {:next, local_expanded, [[], []], []}}

      assert write_state == handler.(msg, state)
    end

    test "moves upwards in the directory hierachy", %{upload: %Upload{handler: handler}, msg: msg} do
      local_dir = @local |> Path.expand() |> Path.join("local_dir")
      local_expanded = @local |> Path.expand()
      state = {:next, local_dir, [[], []], []}

      assert {:cont, 'E\n', {:next, ^local_expanded, [[]], []}} = handler.(msg, state)
    end

    test "finalizes the upload", %{upload: %Upload{handler: handler}, msg: msg} do
      local_expanded = @local |> Path.expand()
      state = {:next, local_expanded, [[]], []}

      assert {:cont, :eof, done_state} = handler.(msg, state)
      assert done_state == {:done, nil, []}

      exit_msg = {:exit_status, @chan, 0}
      assert {:cont, exit_state} = handler.(exit_msg, done_state)
      assert exit_state == {:done, 0, []}

      eof_msg = {:eof, @chan}
      assert {:cont, eof_state} = handler.(eof_msg, exit_state)
      assert eof_state == {:done, 0, []}

      closed_msg = {:closed, @chan}
      assert {:cont, :ok} == handler.(closed_msg, eof_state)
    end

    test "aggregates warnings in the state", %{upload: %Upload{handler: handler, state: {name, cwd, stack, _errs} = state}} do
      error_msg = "error part 1 error part 2 error part 3"

      msg1 = {:data, @chan, 0, <<1, "error part 1 ">>}
      state1 = {:warning, state, "error part 1 "}
      assert {:cont, state1} == handler.(msg1, state)

      msg2 = {:data, @chan, 0, <<"error part 2 ">>}
      state2 = {:warning, state, "error part 1 error part 2 "}
      assert {:cont, state2} == handler.(msg2, state1)

      msg3 = {:data, @chan, 0, <<"error part 3\n">>}
      assert {:cont, {name, cwd, stack, [error_msg]}} == handler.(msg3, state2)
    end

    test "aggregates connection errors in the state and halts", %{upload: %Upload{handler: handler, state: state}} do
      error_msg = "error part 1 error part 2 error part 3"

      msg1 = {:data, @chan, 0, <<2, "error part 1 ">>}
      state1 = {:fatal, state, "error part 1 "}
      assert {:cont, state1} == handler.(msg1, state)

      msg2 = {:data, @chan, 0, <<"error part 2 ">>}
      state2 = {:fatal, state, "error part 1 error part 2 "}
      assert {:cont, state2} == handler.(msg2, state1)

      msg3 = {:data, @chan, 0, <<"error part 3\n">>}
      assert {:halt, {:error, error_msg}} == handler.(msg3, state2)
    end
  end
end
