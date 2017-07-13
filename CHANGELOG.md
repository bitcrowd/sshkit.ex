# SSHKit Changelog

Presented in reverse chronological order.

## master

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.2...HEAD

### Deprecations:

* Put deprecations here

### Potentially breaking changes:

* Put potentially breaking changes here

### New features:

* Added support for uploading/downloading files via the `SSHKIT` main DSL [#32]
* Added support for options that are shared between hosts [#61]
* Improved documentation [#67]
* Added support for passing an anonymous function to `SSH.connect` [#72]
* Add support for passing a `dry_run` flag to `SSHKit.SSH.connect` [#79]

### Fixes:

* Properly return `{:error, "No host given."}` when trying to connect to a host which is `nil` [#70]
* Improved unit and integration tests [#59] [#75] [#77]

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
