# generic elixir utility functions (stuff that should be in the standard lib really)
defmodule Util do
  @moduledoc "Provides project wide utility functions."

  @spec ok_or_error(result :: {:ok, return} | {:error, any}, exn :: module, String.t()) ::
          return
        when return: any
  def ok_or_error({:ok, x}, _, _), do: x

  def ok_or_error({:error, error}, exn, error_msg) do
    raise exn, message: error_msg, error: error
  end

  @spec ok_or(result :: {:ok, any} | {:error, any}, f :: function) :: any
  def ok_or({:ok, x}, _), do: x
  def ok_or({:error, _}, f), do: f.()

  @spec ok_or_nil(result :: {:ok, return} | {:error, any}) :: return | nil when return: any
  def ok_or_nil({:ok, x}), do: x
  def ok_or_nil({:error, _}), do: nil

  @doc "Tests if a module exists. If called inside a macro, this will check if the module is compiled yet without triggering the module adding the module to the current dependency graph."
  @spec module_exists?(module) :: boolean
  def module_exists?(mod) do
    mod.__info__(:attributes)
    true
  rescue
    UndefinedFunctionError ->
      false
  end

  @doc "Tests to see if `mod` implements the given `behaviour`. Works both in and out of macros."
  @spec has_behaviour?(module, module) :: boolean
  def has_behaviour?(mod, behaviour) do
    # if the module is compiled, then we expect the behaviour to be available via reflection attributes
    Keyword.get(mod.__info__(:attributes), :behaviour, [])
    |> Enum.member?(behaviour)
  rescue
    # triggered by [:__info__] if still compiling (in macro) or does not exist
    UndefinedFunctionError ->
      # if the module is still being compiled, we can inspect the modules actual attributes in more detail
      behaviours = Module.get_attribute(mod, :behaviour)
      Enum.member?(behaviours, behaviour)
    # triggered by Module.get_attribute if already compiled (not in macro) or does not exist
    ArgumentError ->
      # at this point, the module just doesn't exist
      false

  end

  defmodule ForMacros do
    @moduledoc "Macro specific utility functions."

    @spec resolve_module(Macro.Env.t(), module() | Macro.t()) :: module()
    def resolve_module(_, mod) when is_atom(mod) do
      Code.ensure_compiled(mod)
      mod
    end

    def resolve_module(env, ast) do
      {mod, []} = Code.eval_quoted(ast, [], env)

      if not is_atom(mod) do
        raise ArgumentError, "failed to resolve super class module"
      end

      Code.ensure_compiled(mod)
      mod
    end
  end
end
