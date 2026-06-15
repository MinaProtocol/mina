let name = "local-apps"

module Network = Local_network
module Network_config = Mina_local.Network_config
module Network_manager = Mina_local.Network_manager

module Log_engine =
  Integration_test_lib.Graphql_polling_log_engine
  .Make_GraphQL_polling_log_engine
    (Local_network)
