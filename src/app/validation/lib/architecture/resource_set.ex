defmodule Architecture.ResourceSet do
  @moduledoc """
  An indexed, queryable set of resources. Supports computing filters for all resources in the set.
  """

  alias Architecture.Resource

  use Class

  @type resource_id :: integer

  # NB:
  #   with this design, uniqueness is only guaranteed within a single set, not across sets
  #   (should be fine for now, needs to use a max_resource_id agent if use-case changes)
  defclass(
    max_resource_id: integer,
    resources: %{optional(resource_id) => Resource.t()},
    class_index: %{optional(Resource.class()) => [resource_id]}
  )

  @spec empty :: t
  def empty,
    do: %__MODULE__{
      max_resource_id: -1,
      resources: %{},
      class_index: %{}
    }

  @spec build([Class.instance()]) :: t
  def build(resources), do: Enum.reduce(resources, empty(), &insert(&2, &1))

  # insertion is private to enforce correct usage
  # (please see NB at defclass if considering exposing publicly)
  @spec insert(t, Class.instance()) :: t
  defp insert(set, resource) do
    id = set.max_resource_id + 1
    resource_class = Class.class_of(resource)
    all_classes = [resource_class | Class.all_super_classes(resource_class)]
    # there's no reason to index the root object or root resource
    # TODO: Class.super_classes_up_to()
    indexable_classes = Enum.filter(all_classes, &(&1 != Class.Object and &1 != Resource))
    resources = Map.put(set.resources, id, resource)

    class_index =
      Enum.reduce(
        indexable_classes,
        set.class_index,
        &Map.update(&2, &1, [], fn ids -> [id | ids] end)
      )

    %{set | max_resource_id: id, resources: resources, class_index: class_index}
  end

  @spec all_resources(t) :: [Resource.t()]
  def all_resources(set), do: Map.values(set.resources)

  @spec all_resource_classes(t) :: [Class.t()]
  def all_resource_classes(set), do: Map.keys(set.class_index)

  @spec select(t, Class.t()) :: t
  def select(set, class), do: slice(set, Map.get(set.class_index, class, []))

  @spec slice(t, [resource_id]) :: t
  defp slice(set, ids) do
    {resources, _} = Map.split(set.resources, ids)

    class_index =
      Enum.map(set.class_index, fn {class, index} ->
        {class, Enum.filter(index, &Enum.member?(ids, &1))}
      end)
      |> Map.new()

    %__MODULE__{set | resources: resources, class_index: class_index}
  end

  @spec filter(t) :: Architecture.LogFilter.t()
  def filter(set) do
    import Architecture.LogFilter

    # need to crawl a tree of class relationships in order to build the proper filter expression
    # for each resource, nest with least descriptive class on the outer, and most descriptive class inner
    # eg:
    #
    #   (
    #     CodaNode.global_filter
    #     AND (
    #       (
    #         BlockProducer.global_filter
    #         AND ((BlockProducer.local_filter AND CodaNode.local_filter) OR ...))
    #       OR (...)
    #       OR (CodaNode.local_filter OR ...))
    #
    # the disjunction of local filter, resource specific filters gets pushed to the most descriptive class's layer, and
    # the adjunctions are nested in a tree following the subclass relationships up to Architecture.Resource

    resource_filters_by_class =
      all_resources(set)
      |> Enum.reduce(%{}, fn resource, map ->
        resource_class = Class.class_of(resource)

        local_filter =
          Class.inheritance_chain!(resource_class, Resource)
          |> Enum.reverse()
          |> Enum.map(fn class -> class.local_filter(Class.downcast!(resource, class)) end)
          |> adjoin()

        if local_filter != nil do
          Map.update(map, resource_class, [local_filter], &(&1 ++ [local_filter]))
        else
          map
        end
      end)

    Class.Hiearchy.compute(Resource, all_resource_classes(set))
    |> Class.Hiearchy.reduce_depth_first_exclusive(
      nil,
      fn class, child_filters ->
        resource_filters = Map.get(resource_filters_by_class, class)

        adjoin(
          class.global_filter(),
          disjoin(disjoin(resource_filters), child_filters)
        )
      end,
      &disjoin/1
    )
  end
end
