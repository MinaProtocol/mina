defmodule Architecture.Resource do
  @moduledoc "Behaviour and mixin for resources."

  import Util.ForMacros

  use Class
  defclass([])

  @type class :: Class.t()

  @spec is_resource_class?(module) :: boolean
  def is_resource_class?(mod), do: Class.is_subclass?(mod, __MODULE__)

  @callback global_filter :: Architecture.LogFilter.t()
  @callback local_filter(any) :: Architecture.LogFilter.t()

  defmacro __using__(_params) do
    quote do
      @behaviour unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      require unquote(__MODULE__)
      import unquote(__MODULE__)
      require unquote(Architecture.LogFilter.Language)
      import unquote(Architecture.LogFilter.Language)
    end
  end

  defmacro __before_compile__(env) do
    if not Class.is_class?(env.module) do
      raise "must create a class"
    end

    # full_global_filter =
    #   case Module.get_attribute(env.module, :extends) do
    #     nil -> quote do: global_filter()
    #     parent -> quote do: unquote(parent).full_global_filter() ++ global_filter()
    #   end

    quote do
      def full_global_filter do
        # unquote(full_global_filter)
        "TODO"
      end
    end
  end

  @spec defresource(Keyword.t(Macro.t())) :: Macro.t()
  defmacro defresource(fields) when is_list(fields) do
    ensure_not_already_class(__CALLER__.module)
    inject_class(__MODULE__, fields)
  end

  @spec defresource(module, Keyword.t(Macro.t())) :: Macro.t()
  defmacro defresource(super_class, fields) when is_list(fields) do
    ensure_not_already_class(__CALLER__.module)
    super_class = resolve_module(__CALLER__, super_class)

    if not Class.is_class?(super_class) or not is_resource_class?(super_class) do
      raise "superclass must be a resource"
    end

    inject_class(super_class, fields)
  end

  @spec ensure_not_already_class(module) :: nil
  defp ensure_not_already_class(mod) do
    if Class.is_class?(mod) do
      raise "cannot define resource because #{inspect(mod)} is already a class"
    end
  end

  @spec inject_class(module, Keyword.t(Macro.t())) :: Macro.t()
  defp inject_class(super_class, fields) do
    quote do
      use unquote(Class)
      defclass(unquote(super_class), unquote(fields))
    end
  end
end
