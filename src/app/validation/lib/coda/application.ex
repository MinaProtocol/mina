defmodule Coda.Application do
  @moduledoc """
  The root application. Responsible for initializing the process tree.
  """

  alias Architecture.LogFilter
  alias Architecture.ResourceSet
  alias Cloud.Google.LogPipeline
  alias Coda.Resources

  import LogFilter.Language

  use Application

  def resource_db_entries do
    win_rates = Coda.Validations.Configuration.whale_win_rates
    [
      # class, id, expected_win_rate
      Resources.BlockProducer.build("whale", 1, Enum.fetch!(win_rates,0)),
      Resources.BlockProducer.build("whale", 2, Enum.fetch!(win_rates,1)),
      Resources.BlockProducer.build("whale", 3, Enum.fetch!(win_rates,2)),
      Resources.BlockProducer.build("whale", 4, Enum.fetch!(win_rates,3)),
      Resources.BlockProducer.build("whale", 5, Enum.fetch!(win_rates,4))
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

    resource_filter = Architecture.LogProvider.log_filter(Coda.Providers.BlockProduced, resource_db)

    global_filter = filter do
      resource.labels.project_id == "#{Coda.project_id()}"
      resource.labels.location == "#{Coda.location()}"
      resource.labels.cluster_name == "#{Coda.cluster()}"
      resource.labels.namespace_name == "#{Coda.testnet()}"
    end

    log_filter = Architecture.LogFilter.adjoin(global_filter, resource_filter)

    IO.puts("LOG FILTER:")
    IO.puts(LogFilter.render(log_filter))
    IO.puts("===========")

    log_pipeline =
      LogPipeline.create(
        api_conns.pubsub,
        api_conns.logging,
        "blocks-produced",
        LogFilter.render(log_filter)
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
        resource_db: resource_db,
      }
    ]

    log_providers_spec = [
      %Architecture.LogProvider.Spec{
        log_provider: Coda.Providers.BlockProduced,
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
