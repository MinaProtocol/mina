# OOP! (sin methods, constructors, mutation, abstractions -- ok, maybe drop the P and just call it OO)
# TODO: make this less fragile (needs to check that modules is applies functions to are actually classes first)
defmodule Class do
  @moduledoc "A lightweight, immutable, record subtyping relationship and definition system."

  import Util
  import Util.ForMacros

  defmodule NotASubclassError do
    defexception [:class, :expected_subclass_of]

    def message(%__MODULE__{class: class, expected_subclass_of: expected_subclass_of}) do
      "#{class} is not a subclass of #{expected_subclass_of}"
    end
  end

  @type t :: module
  @type instance :: struct

  # Root object (which all classes are a subclass of)

  defmodule Object do
    @moduledoc "The root record type which all class instances are a subtype of."

    defstruct []
    @type t :: %__MODULE__{}
    def parent_class, do: nil
    def __class_fields, do: []
  end

  # Class helper functions

  @spec is_class?(module) :: boolean
  # for some reason, behaviours set from macros do not seem to persist, so this doesn't work:
  #   def is_class?(mod), do: has_behaviour?(mod, __MODULE__)
  def is_class?(mod) do
    if module_exists?(mod) do
      function_exported?(mod, :__class_fields, 0)
    else
      has_behaviour?(mod, __MODULE__)
    end
  end

  @spec is_subclass?(module, module) :: module
  def is_subclass?(c1, c2) when c1 == c2, do: true
  def is_subclass?(Object, _), do: false
  def is_subclass?(c1, c2), do: is_subclass?(c1.parent_class(), c2)

  @spec class_of(instance) :: t
  def class_of(instance) when is_struct(instance), do: instance.__struct__

  @spec instance_of?(instance, t) :: boolean
  def instance_of?(instance, class) when is_struct(instance) do
    is_subclass?(class_of(instance), class)
  end

  @spec downcast!(instance, t) :: instance
  def downcast!(instance, class) do
    cond do
      class == class_of(instance) ->
        instance

      not instance_of?(instance, class) ->
        raise NotASubclassError, class: class_of(instance), expected_subclass_of: class

      true ->
        struct!(class, Map.take(instance, Keyword.keys(class.__class_fields)))
    end
  end

  @spec all_super_classes(t) :: [t]
  def all_super_classes(Object), do: []

  def all_super_classes(class) do
    parent_class = class.parent_class()
    [parent_class | all_super_classes(parent_class)]
  end

  @doc """
    Computes the inheritance chain from `c1` up to `c2`, including `c1` and excluding `c2` (i.e. `[c1,c2)`).
    Returns `nil` if `c1` is not a subclass of `c2`.
  """
  @spec inheritance_chain(c1 :: t, c2 :: t) :: [t] | nil
  def inheritance_chain(c1, c2) when c1 == c2, do: []
  def inheritance_chain(Object, _), do: nil
  def inheritance_chain(c1, c2), do: [c1 | inheritance_chain(c1.parent_class(), c2)]

  @doc """
    Same as `inheritance_chain/2`, but explosive!
    If `c1` is not a subclass of `c2`, a `Class.NotASubclassError` exception is raised."
  """
  @spec inheritance_chain!(c1 :: t, c2 :: t) :: [t]
  def inheritance_chain!(c1, c2) do
    case inheritance_chain(c1, c2) do
      nil -> raise NotASubclassError, class: c1, expected_subclass_of: c2
      chain -> chain
    end
  end

  # Class heiarchy

  defmodule Hiearchy do
    @moduledoc "Tree structure for representing class hiearchies."

    @type t :: {Class.t(), [t]}

    def compute(root_class, leaf_classes) do
      # insert into index
      insert = fn index, class ->
        Map.update(index, class.parent_class(), MapSet.new([class]), &MapSet.put(&1, class))
      end

      index =
        Enum.reduce(leaf_classes, %{root_class => MapSet.new()}, fn leaf_class, index ->
          Class.inheritance_chain!(leaf_class, root_class)
          |> Enum.reduce(index, &insert.(&2, &1))
        end)

      compute_from_index!(root_class, index)
    end

    defp compute_from_index!(target_class, index) do
      children = Map.get(index, target_class, MapSet.new())
      {target_class, Enum.map(MapSet.to_list(children), &compute_from_index!(&1, index))}
    end

    @spec reduce_depth_first(t | Class.t(), any, function, function) :: any
    def reduce_depth_first({leaf, []}, init, lift, _) when is_atom(leaf), do: lift.(leaf, init)

    def reduce_depth_first({root, _} = node, init, lift, merge),
      do: lift.(root, reduce_depth_first_exclusive(node, init, lift, merge))

    @spec reduce_depth_first_exclusive(t | Class.t(), any, function, function) :: any
    def reduce_depth_first_exclusive({_, []}, init, _, _), do: init

    def reduce_depth_first_exclusive({_, leaves}, init, lift, merge) do
      leaves
      |> Enum.map(&reduce_depth_first(&1, init, lift, merge))
      |> merge.()
    end
  end

  # Class definition mixin

  @callback parent_class :: module
  @callback __class_fields :: Keyword.t(Macro.t())

  # TODO: There should be a less complicated way of doing this.
  # I wanted to use mixin params, but it was too messy to differentiate between fields and the parent class to extend.
  defmacro __using__(_params) do
    quote do
      import unquote(__MODULE__)
      require unquote(__MODULE__)
      @before_compile unquote(__MODULE__)
      @behaviour unquote(__MODULE__)
      Module.register_attribute(__MODULE__, :super_class, [])
      Module.register_attribute(__MODULE__, :class_fields, [])
    end
  end

  # TODO: handle field collisions
  defmacro __before_compile__(env) do
    super_class = Module.get_attribute(env.module, :super_class)
    class_fields = Module.get_attribute(env.module, :class_fields)

    if is_nil(super_class) or is_nil(class_fields) do
      raise ArgumentError, "must specify class when using #{__MODULE__} mixin"
    end

    quote do
      @impl true
      def parent_class, do: unquote(super_class)
      @impl true
      def __class_fields, do: unquote(Macro.escape(class_fields))
    end
  end

  defmacro defclass(fields) when is_list(fields) do
    inject_class_info(__CALLER__, Object, fields)
  end

  defmacro defclass(super_class, fields) when is_list(fields) do
    Code.ensure_compiled(resolve_module(__CALLER__, super_class))

    if not Class.is_class?(resolve_module(__CALLER__, super_class)) do
      raise "cannot extend #{super_class} because it is not a class"
    end

    inject_class_info(__CALLER__, super_class, fields)
  end

  defp inject_class_info(env, super_class, local_fields) do
    # TODO: sanity check module definition thus far?

    super_class_module = resolve_module(env, super_class)
    super_class_fields = super_class_module.__class_fields
    class_fields = super_class_fields ++ local_fields
    class_field_names = Keyword.keys(class_fields)

    # %__MODULE__{ class_fields... }
    class_type =
      {:%, [],
       [
         {:__MODULE__, [], Elixir},
         {:%{}, [], class_fields}
       ]}

    quote do
      @enforce_keys unquote(class_field_names)
      defstruct unquote(class_field_names)
      @type t :: unquote(class_type)

      @super_class unquote(Macro.escape(super_class))
      @class_fields unquote(Macro.escape(class_fields))
    end
  end
end
