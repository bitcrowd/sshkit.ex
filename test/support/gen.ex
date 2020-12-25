defmodule Gen do
  @moduledoc false

  @doc """
  Generates a behaviour based on an existing module.

  Mox requires a behaviour to be defined in order to create a mock. To mock
  core modules in tests - e.g. :ssh, :ssh_connection and :ssh_sftp - we need
  behaviours mirroring their public API.
  """
  def defbehaviour(name, target) when is_atom(name) and is_atom(target) do
    info = moduledoc("Generated behaviour for #{inspect(target)}.")

    body =
      for {fun, arity} <- functions(target) do
        args = 0..arity |> Enum.map(fn _ -> {:term, [], []} end) |> tl()

        quote do
          @callback unquote(fun)(unquote_splicing(args)) :: term()
        end
      end

    Module.create(name, info ++ body, Macro.Env.location(__ENV__))
  end

  @doc """
  Generates a module delegating all function calls to another module.

  Mox requires modules used for stubbing to implement the mocked behaviour. To
  mock core modules without behaviour definitions, we generate stand-in modules
  which delegate
  """
  def defdelegated(name, target, options \\ [])
      when is_atom(name) and is_atom(target) and is_list(options) do
    info =
      moduledoc("Generated stand-in module for #{inspect(target)}.") ++
        behaviour(Keyword.get(options, :behaviour))

    body =
      for {fun, arity} <- functions(target) do
        args = Macro.generate_arguments(arity, name)

        quote do
          defdelegate unquote(fun)(unquote_splicing(args)), to: unquote(target)
        end
      end

    Module.create(name, info ++ body, Macro.Env.location(__ENV__))
  end

  defp functions(module) do
    exports = module.module_info(:exports)
    Keyword.drop(exports, ~w[__info__ module_info]a)
  end

  defp moduledoc(nil), do: []
  defp moduledoc(docstr), do: [quote(do: @moduledoc(unquote(docstr)))]

  defp behaviour(nil), do: []
  defp behaviour(name), do: [quote(do: @behaviour(unquote(name)))]
end
