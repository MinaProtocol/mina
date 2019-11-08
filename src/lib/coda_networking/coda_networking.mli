open Coda_base

val refused_answer_query_string : string

type exn += No_initial_peers

module type Config_intf = sig
  type gossip_config

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; gossip_net_params: gossip_config
    ; time_controller: Block_time.Controller.t
    ; consensus_local_state: Consensus.Data.Local_state.t }
end

include
  Coda_intf.Network_intf
  with type snark_pool_diff = Network_pool.Snark_pool.Resource_pool.Diff.t
   and type transaction_pool_diff =
              Network_pool.Transaction_pool.Resource_pool.Diff.t
