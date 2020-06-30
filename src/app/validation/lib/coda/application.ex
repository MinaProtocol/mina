defmodule Coda.Application do
  @moduledoc """
  The root application. Responsible for initializing the process tree.
  """

  alias Architecture.LogFilter
  alias Architecture.ResourceSet
  alias Cloud.Google.LogPipeline
  alias Coda.Resources

  use Application

  def resource_db_entries do
    [
      Resources.BlockProducer.build("whale", 1),
      Resources.BlockProducer.build("whale", 2),
      Resources.BlockProducer.build("whale", 3),
      Resources.BlockProducer.build("whale", 4),
      Resources.BlockProducer.build("whale", 5)
      # Resources.BlockProducer.build("fish", 1),
      # Resources.BlockProducer.build("fish", 2),
      # Resources.BlockProducer.build("fish", 3)
    ]
  end

  def start(_, _) do
    {:ok, _started} = Application.ensure_all_started(:goth)
    :httpc.set_options(pipeline_timeout: 1000)

    api_conns = Cloud.Google.connect()

    # TODO: derive all of this from validations + resource query
    resource_db = ResourceSet.build(resource_db_entries())

    # validation_requests = [Validations.GlobalBlockAcceptanceRate]
    # requirements ==>
    #   Validations.GlobalBlockAcceptanceRate
    #   > Statistics.GlobalBlockAcceptanceRate
    #     > forall(r : resources).
    #         {Statistics.BlockAcceptanceRate, r}
    #         > {Statistics.BlocksProduced, r}
    #           > {Providers.BlockProduced, r}
    #         > Statistics.GlobalFrontier
    #           > forall(r2 : resources).
    #               {Statistics.Frontier, r2}
    #                 > {Providers.FrontierDiffApplied, r2}
    # validations ==> [
    #   Validations.GlobalBlockAcceptanceRate
    # ]
    # statistics ==> [
    #   Statistics.GlobalBlockAcceptanceRate,
    #   {Statistic.BlockAcceptanceRate, resources},
    #   {Statistics.BlocksProduced, resources},
    #   Statistics.GlobalFrontier,
    #   {Statistics.Frontier, resources}
    # ]
    # providers ==> [
    #   {Providers.BlockProduced, resources}
    #   {Providers.BlockFrontierDiffApplied, resources}
    # ]

    filter = Architecture.LogProvider.log_filter(Coda.Providers.BlockProduced, resource_db)

    IO.puts("LOG FILTER:")
    IO.puts(LogFilter.render(filter))
    IO.puts("===========")

    log_pipeline =
      LogPipeline.create(
        api_conns.pubsub,
        api_conns.logging,
        "blocks-produced",
        LogFilter.render(filter)
      )

    validations_spec = [
      %Architecture.Validation.Spec{
        validation: Coda.Validations.BlockProductionRate,
        resource_db: resource_db
      }
    ]

    statistics_spec = [
      # in theory, resource db queries can be performed separately for each stat config
      %Architecture.Statistic.Spec{
        statistic: Coda.Statistics.BlockProductionRate,
        resource_db: resource_db
      }
    ]

    log_providers_spec = [
      %Architecture.LogProvider.Spec{
        log_provider: Coda.LogProvider.BlockProduced,
        subscription: log_pipeline.subscription,
        conn: api_conns.pubsub
      }
    ]

    children = [
      # {Architecture.AlertServer, []},
      {Architecture.LogProvider.MainSupervisor, log_providers_spec},
      {Architecture.Statistic.MainSupervisor, statistics_spec},
      {Architecture.Validation.MainSupervisor, validations_spec}
    ]

    # TODO: should the strategy here be :one_for_rest?
    Supervisor.start_link(children, name: __MODULE__, strategy: :one_for_one)
  end
end
