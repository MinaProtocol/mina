defmodule Architecture.ResourceDatabase do
  @moduledoc """
  An indexed, queryable set of resources. Supports computing filters for all resources in the
  database.
  """

  alias Architecture.Resource

  use Class

  @type resource_id :: integer

  # NB:
  #   with this design, uniqueness is only guaranteed within a single database, not across databases
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
  defp insert(db, resource) do
    id = db.max_resource_id + 1
    resource_class = Class.class_of(resource)
    all_classes = [resource_class | Class.all_super_classes(resource_class)]
    # there's no reason to index the root object or root resource
    # TODO: Class.super_classes_up_to()
    indexable_classes = Enum.filter(all_classes, &(&1 != Class.Object and &1 != Resource))
    resources = Map.put(db.resources, id, resource)

    class_index =
      Enum.reduce(
        indexable_classes,
        db.class_index,
        &Map.update(&2, &1, [], fn ids -> [id | ids] end)
      )

    %{db | max_resource_id: id, resources: resources, class_index: class_index}
  end

  @spec all_resources(t) :: [Resource.t()]
  def all_resources(db), do: Map.values(db.resources)

  @spec all_resource_classes(t) :: [Class.t()]
  def all_resource_classes(db), do: Map.keys(db.class_index)

  @spec select(t, Class.t()) :: t
  def select(db, class), do: slice(db, Map.get(db.class_index, class, []))

  @spec slice(t, [resource_id]) :: t
  defp slice(db, ids) do
    {resources, _} = Map.split(db.resources, ids)

    class_index =
      Enum.map(db.class_index, fn {class, index} ->
        {class, Enum.filter(index, &Enum.member?(ids, &1))}
      end)
      |> Map.new()

    %__MODULE__{db | resources: resources, class_index: class_index}
  end

  @spec filter(t) :: Architecture.LogFilter.t()
  def filter(db) do
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
      all_resources(db)
      |> Enum.reduce(%{}, fn resource, map ->
        resource_class = Class.class_of(resource)

        local_filters =
          Class.inheritance_chain!(resource_class, Resource)
          |> Enum.map(fn class -> class.local_filter(Class.downcast!(resource, class)) end)

        if length(local_filters) > 0 do
          Map.update(map, resource_class, [], &[adjoin(local_filters) | &1])
        else
          map
        end
      end)

    Class.Hiearchy.compute(Resource, all_resource_classes(db))
    |> Class.Hiearchy.reduce_depth_first_exclusive(
      nil,
      fn class, child_filters ->
        resource_filters = Map.get(resource_filters_by_class, class)

        adjoin(
          class.global_filter(),
          disjoin(child_filters, disjoin(resource_filters))
        )
      end,
      &disjoin/1
    )
  end
end
