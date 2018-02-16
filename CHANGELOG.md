# SSHKit Changelog

Presented in reverse chronological order.

## master

https://github.com/bitcrowd/sshkit.ex/compare/v0.1.0...HEAD

* Put high-level summary here

### Deprecations:

* Put deprecations here

### Potentially breaking changes:

* Put potentially breaking changes here

### New features:

* Put new features here

### Fixes:

* Put fixes here

## `0.1.0` (work in progress)

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.3...v0.1.0

* Require Elixir 1.5+ and drop support for lower versions.
* Fix Elixir 1.5 String deprecations.
* Update installation instructions.
* Introduce Mox for mocking in unit tests.
* Improve and add unit tests.

### Potentially breaking changes:

* Remove `:dry_run` option for now. Planning to reintroduce at a higher level.
* Set `-H` option for `sudo` in order to get the expected value for `HOME`

### New features:

* Put new features here

### Fixes:

* Fix error handling in `SSHKit.SSH.Channel.send/4` when sending stream data
* Context properly handles the case where env is set to an empty map

## `0.0.3` (2017-07-13)

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.2...v0.0.3

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
