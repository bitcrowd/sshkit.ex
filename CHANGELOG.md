# SSHKit Changelog

Presented in reverse chronological order.

## master

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.2...HEAD

### Deprecations:

* Put deprecations here

### Potentially breaking changes:

* Put potentially breaking changes here

### New features:

* Put new features here

### Fixes:

* Put fixes here

## `0.0.2` (2017-06-23)

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.1...v0.0.2

### Potentially breaking changes:

* Renamed response from remotely executed commands from 'normal' to 'stdout' [#34]
* Renamed `SSHKit.pwd` to `SSHKit.path` [#33] Thanks @brienw for the idea

### New features:

* Support basic SCP up-/downloads
* Added documentation https://hexdocs.pm/sshkit/SSHKit.html

### Fixes:

* Accept binaries (not only charlists) for configuration. Thanks @svoynow
* Fixed a bug that prevented `SSHKit.env` from working [#35]

## `0.0.1` (2017-01-26)

https://github.com/bitcrowd/sshkit.ex/releases/tag/v0.0.1

Basic support of / wrapping around erlang :ssh.
