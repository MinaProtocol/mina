let name = "cloud"

module Network = Kubernetes_network
module Network_config = Mina_automation.Network_config
module Network_manager = Mina_automation.Network_manager

module Log_engine =
  Integration_test_lib.Graphql_polling_log_engine
  .Make_GraphQL_Polling_log_engine
    (Kubernetes_network)
