defmodule ErlangSshBehaviour do
  @moduledoc false

  @type conn() :: term()

  @callback connect(binary(), integer(), keyword(), timeout()) :: {:ok, conn()} | {:error, term()}
  @callback close(conn()) :: :ok
end

defmodule ErlangSsh do
  @moduledoc false

  @behaviour ErlangSshBehaviour

  defdelegate connect(host, port, options, timeout), to: :ssh
  defdelegate close(conn), to: :ssh
end

Mox.defmock(MockErlangSsh, for: ErlangSshBehaviour)

defmodule ErlangSshConnectionBehaviour do
  @moduledoc false

  @type conn() :: term()
  @type chan() :: integer()

  @callback session_channel(conn(), integer(), integer(), timeout()) ::
              {:ok, chan()} | {:error, term()}
  @callback subsystem(conn(), chan(), charlist(), timeout()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback close(conn(), chan()) :: :ok
  @callback exec(conn(), chan(), binary(), timeout()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback ptty_alloc(conn(), chan(), keyword(), timeout()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback send(conn(), chan(), 0..1, binary(), timeout()) ::
              :ok | {:error, :timeout} | {:error, :closed}
  @callback send_eof(conn(), chan()) :: :ok | {:error, :closed}
  @callback adjust_window(conn(), chan(), integer()) :: :ok
end

defmodule ErlangSshConnection do
  @moduledoc false

  @behaviour ErlangSshConnectionBehaviour

  defdelegate session_channel(conn, initial_window_size, max_packet_size, timeout),
    to: :ssh_connection

  defdelegate subsystem(conn, chan, name, timeout), to: :ssh_connection
  defdelegate close(conn, chan), to: :ssh_connection
  defdelegate exec(conn, chan, command, timeout), to: :ssh_connection
  defdelegate ptty_alloc(conn, chan, keyword, timeout), to: :ssh_connection
  defdelegate send(conn, chan, type, data, timeout), to: :ssh_connection
  defdelegate send_eof(conn, chan), to: :ssh_connection
  defdelegate adjust_window(conn, chan, size), to: :ssh_connection
end

Mox.defmock(MockErlangSshConnection, for: ErlangSshConnectionBehaviour)

defmodule ErlangSshSftpBehaviour do
  @moduledoc false

  @type conn() :: term()
  @type chan() :: pid()

  # TODO
  @callback start_channel(conn(), keyword()) :: {:ok, chan()} | {:error, term()}
end

defmodule ErlangSshSftp do
  @moduledoc false

  @behaviour ErlangSshSftpBehaviour

  defdelegate start_channel(conn, options), to: :ssh_sftp
end

Mox.defmock(MockErlangSshSftp, for: ErlangSshSftpBehaviour)
