require Gen

Gen.defbehaviour(ErlangSsh.Behaviour, :ssh)
Gen.defdelegated(ErlangSsh, :ssh, behaviour: ErlangSsh.Behaviour)
Mox.defmock(MockErlangSsh, for: ErlangSsh.Behaviour)

Gen.defbehaviour(ErlangSshConnection.Behaviour, :ssh_connection)
Gen.defdelegated(ErlangSshConnection, :ssh_connection, behaviour: ErlangSshConnection.Behaviour)
Mox.defmock(MockErlangSshConnection, for: ErlangSshConnection.Behaviour)

Gen.defbehaviour(ErlangSshSftp.Behaviour, :ssh_sftp)
Gen.defdelegated(ErlangSshSftp, :ssh_sftp, behaviour: ErlangSshSftp.Behaviour)
Mox.defmock(MockErlangSshSftp, for: ErlangSshSftp.Behaviour)
