# SSHKit

[![Build Status](https://travis-ci.org/bitcrowd/sshkit.ex.svg?branch=master)](https://travis-ci.org/bitcrowd/sshkit.ex)
[![Inline docs](https://inch-ci.org/github/bitcrowd/sshkit.ex.svg?branch=master)](https://inch-ci.org/github/bitcrowd/sshkit.ex)

SSHKit is an Elixir toolkit for performing tasks on one or more servers,
built on top of Erlang’s SSH application.

[Documentation for SSHKit is available online](https://hexdocs.pm/sshkit).

## Usage (work in progress)

SSHKit is designed to enable server task automation in a structured and
repeatable way, e.g. in the context of deployment tools:

```elixir
hosts = ["1.eg.io", {"2.eg.io", port: 2222}]

context =
  SSHKit.context(hosts)
  |> SSHKit.path("/var/www/phx")
  |> SSHKit.user("deploy")
  |> SSHKit.group("deploy")
  |> SSHKit.umask("022")
  |> SSHKit.env(%{"NODE_ENV" => "production"})

:ok = SSHKit.upload(context, ".", recursive: true)
:ok = SSHKit.run(context, "yarn install")
```

The [`SSHKit`](https://hexdocs.pm/sshkit/SSHKit.html) module documentation has
more guidance and examples for the DSL.

If you need more control, take a look at the `SSHKit.SSH` and `SSHKit.SCP`
modules.

## Installation

You can use SSHKit in your projects in two steps:

1. Add `sshkit` to your `mix.exs` dependencies:

  ```elixir
  def deps do
    [{:sshkit, "~> 0.0.2"}]
  end
  ```

2. List `sshkit` in your application dependencies:

  ```elixir
  def application do
    [applications: [:sshkit]]
  end
  ```

## Testing

As usual, to run all tests, use:

```shell
mix test
```

Apart from unit tests, we also have
[functional tests](https://en.wikipedia.org/wiki/Functional_testing).
These check SSHKit functionality against real SSH server implementations
running inside Docker containers. Therefore, you need to have
[Docker](https://www.docker.com/) installed.

All functional tests are tagged as such. Hence, if you wish to skip them:

```shell
mix test --exclude functional
```

Hint: We've found functional tests to run significantly faster with
[Docker Machine](https://docs.docker.com/machine/) compared to
[Docker for Mac](https://docs.docker.com/docker-for-mac/) on OS X.

## Contributing

We welcome everyone to contribute to SSHKit and help us tackle existing issues!

Use the [issue tracker][issues] for bug reports or feature requests.
Open a [pull request][pulls] when you are ready to contribute.

If you are planning to contribute documentation, please check
[the best practices for writing documentation][writing-docs].

## License

SSHKit source code is released under the MIT License.
Check the [LICENSE](LICENSE) file for more information.

  [issues]: https://github.com/bitcrowd/sshkit.ex/issues
  [pulls]: https://github.com/bitcrowd/sshkit.ex/pulls
  [writing-docs]: http://elixir-lang.org/docs/stable/elixir/writing-documentation.html
