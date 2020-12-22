use Mix.Config

if Mix.env() == :test do
  config :sshkit, :ssh, MockErlangSsh
  config :sshkit, :ssh_connection, MockErlangSshConnection
  config :sshkit, :ssh_sftp, MockErlangSshSftp
end
