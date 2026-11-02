let name = "native"

module Network = Native_network
module Network_config = Mina_native.Network_config
module Network_manager = Mina_native.Network_manager

module Log_engine =
  Integration_test_lib.Graphql_polling_log_engine
  .Make_GraphQL_polling_log_engine
    (Native_network)
