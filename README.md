# SSHKit

[![Build Status](https://travis-ci.org/bitcrowd/sshkit.ex.svg?branch=master)](https://travis-ci.org/bitcrowd/sshkit.ex)
[![Inline docs](https://inch-ci.org/github/bitcrowd/sshkit.ex.svg?branch=master)](https://inch-ci.org/github/bitcrowd/sshkit.ex)

SSHKit is an Elixir toolkit for performing tasks on one or more servers, built on top of Erlang’s SSH application.

[Documentation for SSHKit is available online][docs].

## Usage

SSHKit is designed to enable server task automation in a structured and repeatable way, e.g. in the context of deployment tools:

```elixir
hosts = ["1.eg.io", {"2.eg.io", port: 2222}]

{:ok, conn} = SSHKit.connect(hosts)

{:ok, _} = SSHKit.run(conn, "apt-get update -y")

{:ok, } = SSHKit.stream(chan)

context =
  SSHKit.context()
  |> SSHKit.path("/var/www/phx")
  |> SSHKit.user("deploy")
  |> SSHKit.group("deploy")
  |> SSHKit.umask("022")
  |> SSHKit.env(%{"NODE_ENV" => "production"})

{:ok, _} = SSHKit.upload(conn, ".", recursive: true, context: context)

# TODO: Receive upload status messages

{:ok, chan} = SSHKit.run(conn, "yarn install", context: context)

# TODO: Showcase streaming interface

:ok = SSHKit.close(conn)
```

The [`SSHKit`](https://hexdocs.pm/sshkit/SSHKit.html) module documentation has more guidance and examples for the DSL.

## Installation

Just add `sshkit` to your list of dependencies in `mix.exs`:

  ```elixir
  def deps do
    [{:sshkit, "~> 1.0"}]
  end
  ```

SSHKit should be automatically started unless the `:applications` key is set inside `def application` in your `mix.exs`. In such cases, you need to [remove the `:applications` key in favor of `:extra_applications`](https://elixir-lang.org/blog/2017/01/05/elixir-v1-4-0-released/#application-inference).

## Testing

As usual, to run all tests, use:

```shell
mix test
```

Apart from unit tests, we also have [functional tests](https://en.wikipedia.org/wiki/Functional_testing). These check SSHKit against real SSH server implementations running inside Docker containers. Therefore, you need to have [Docker](https://www.docker.com/) installed.

All functional tests are tagged as such. Hence, if you wish to skip them:

```shell
mix test --exclude functional
```

Hint: We've found functional tests to run significantly faster with [Docker Machine](https://docs.docker.com/machine/) compared to [Docker for Mac](https://docs.docker.com/docker-for-mac/) on OS X.

## Releasing

* Make sure tests pass: `mix test`.
* Increase version number in `mix.exs`, keeping [semantic versioning](https://semver.org/) in mind.
* Update [CHANGLOG.md][changelog]:
  * Create a new section for the current version.
  * Reset the `master` section to the empty template.
* Commit your changes: `git commit -m "Release 0.1.0"`.
* Tag the commit with the version number: `git tag -a v0.1.0`.
  * Annotate the tag with the respective section from [CHANGLOG.md][changelog] *(in a git-compatible format)*.
* Push your commit: `git push`.
* Push the tag: `git push origin v0.1.0`
* Publish the new release to hex.pm: `mix hex.publish`.
  * You can find the hex.pm credentials in the bitcrowd password store.

## Contributing

We welcome everyone to contribute to SSHKit and help us tackle existing issues!

Use the [issue tracker][issues] for bug reports or feature requests. Open a [pull request][pulls] when you are ready to contribute.

If you are planning to contribute documentation, please check [the best practices for writing documentation][writing-docs].

## Thanks

SSHKit is inspired by [SSHKit for Ruby](https://github.com/capistrano/sshkit) which is part of the fantastic [Capistrano](https://github.com/capistrano) project.

It deliberately departs from its role model with regard to its API given the very different nature of the two programming languages.

If you are looking for an Elixir deployment tool similar to Capistrano, take a look at [Bootleg](https://github.com/labzero/bootleg) which is based on top of SSHKit.

## License

SSHKit source code is released under the MIT License.

Check the [LICENSE][license] file for more information.

[issues]: https://github.com/bitcrowd/sshkit.ex/issues
[pulls]: https://github.com/bitcrowd/sshkit.ex/pulls
[docs]: https://hexdocs.pm/sshkit
[changelog]: ./CHANGELOG.md
[license]: ./LICENSE
[writing-docs]: https://hexdocs.pm/elixir/writing-documentation.html
