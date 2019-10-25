# SSHKit Changelog

Presented in reverse chronological order.

## master

https://github.com/bitcrowd/sshkit.ex/compare/v0.2.0...HEAD

<!-- Put high-level summary here -->

<!-- Give thanks to contributors and mention them! -->

### Deprecations:

<!-- Put deprecations here -->

### Potentially breaking changes:

<!-- Put potentially breaking changes here -->

### New features:

<!-- Put new features here -->
* Add support for initializing subsystems using `SSH.Channel.subsystem`
  * Subsystems allow applications or functions to use SSH as a protocol.
    Examples of this are SFTP and NETCONF over SSH.

### Fixes:

<!-- Put fixes here -->

## `0.2.0` (2019-10-17)

https://github.com/bitcrowd/sshkit.ex/compare/v0.1.0...v0.2.0

* The `SSHKit.download/3` and `SSHKit.upload/3` functions are now fully context-aware [#121]
* They will respect the `user`, `env`, `path`… values set in the context

### Fixes:

* Improve documentation about our release process
* Fix an Elixir 1.8 deprecation warning (#147)

## `0.1.0` (2018-09-18)

https://github.com/bitcrowd/sshkit.ex/compare/v0.0.3...v0.1.0

* Require Elixir 1.5+ and drop support for lower versions.
* Fix Elixir 1.5 String deprecations.
* Update installation instructions.
* Introduce Mox for mocking in unit tests.
* Improve and add unit tests.

Thanks for your contributions:

* @Bugagazavr
* @brienw
* @holetse

### Potentially breaking changes:

* Remove `:dry_run` option: Depending on how you're using SSHKit, "dry-run" could have a number of different meanings
  * you may want to actually connect to the remote without changing anything or you may not want to establish a connection at all
  * some steps in the flow you're dry-running may depend on things like directories created in a previous step which won't be there
  * all in all, a "dry-run" feature is likely better handled at an application level which may know the dependencies between commands
* Set `-H` option for `sudo` in order to get the expected value for `HOME`
* Export context environment variables directly before the supplied command in `SSHKit.Context.build/2`
  * this could potentially result in different behavior for code that sets environment variables consumed by the other commands in the context
  * those cases should be rare though and the new behavior seems closer to what most would expect when using contexts

### New features:

* Split the SCP file upload into a setup and an execution step:
  * add `SCP.Upload.new/3` and `SCP.Upload.exec/2`
  * `SCP.Upload.transfer/4` still works as before
* Added support for ptty allocation in `SSH.Channel` module [#129]

### Fixes:

* Fix error handling in `SSHKit.SSH.Channel.send/4` when sending stream data
* Context properly handles the case where env is set to an empty map
* Fix environment variables export in contexts with user, group, umask, path and env

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
