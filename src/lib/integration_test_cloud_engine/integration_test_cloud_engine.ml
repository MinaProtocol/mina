let name = "cloud"

module Network = Kubernetes_network
module Network_config = Mina_automation.Network_config
module Network_manager = Mina_automation.Network_manager

module Kubernetes_polling_interval = struct
  let start_filtered_logs_interval = Core.Time.Span.of_sec 10.0
end

module Log_engine =
  Integration_test_lib.Graphql_polling_log_engine
  .Make_GraphQL_polling_log_engine
    (Kubernetes_network)
    (Kubernetes_polling_interval)
