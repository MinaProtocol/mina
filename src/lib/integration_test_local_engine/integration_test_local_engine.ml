let name = "local"

module Network = Docker_network
module Network_config = Mina_docker.Network_config
module Network_manager = Mina_docker.Network_manager

module Docker_polling_interval = struct
  let interval = Core.Time.Span.of_sec 0.25
end

module Log_engine =
  Integration_test_lib.Graphql_polling_log_engine
  .Make_GraphQL_polling_log_engine
    (Docker_network)
    (Docker_polling_interval)
