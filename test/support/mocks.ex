defmodule SSHKit.Connection.Impl do
  @moduledoc false

  @type conn :: any()

  @callback connect(binary(), integer(), keyword(), timeout()) :: {:ok, conn} | {:error, any()}
  @callback close(conn) :: :ok
end

Mox.defmock(SSHKit.Connection.ImplMock, for: SSHKit.Connection.Impl)

defmodule SSHKit.Channel.Impl do
  @moduledoc false

  @type conn :: any()
  @type chan :: integer()

  @callback session_channel(conn, integer(), integer(), timeout()) ::
              {:ok, chan} | {:error, any()}
  @callback subsystem(conn, chan, charlist(), keyword()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback close(conn, chan) :: :ok
  @callback exec(conn, chan, binary(), timeout()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback ptty_alloc(conn, chan, keyword(), timeout()) ::
              :success | :failure | {:error, :timeout} | {:error, :closed}
  @callback send(conn, chan, 0..1, binary(), timeout()) ::
              :ok | {:error, :timeout} | {:error, :closed}
  @callback send_eof(conn, chan) :: :ok | {:error, :closed}
  @callback adjust_window(conn, chan, integer()) :: :ok
  @callback shell(conn, chan) :: :ok | {:error, :closed}
end

Mox.defmock(SSHKit.Channel.ImplMock, for: SSHKit.Channel.Impl)
