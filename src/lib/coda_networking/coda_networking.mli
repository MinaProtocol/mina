open Coda_base

val refused_answer_query_string : string

type exn += No_initial_peers

module type Inputs_intf = sig
  module Snark_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t

    val compact_json : t -> Yojson.Safe.json
  end

  module Transaction_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t
  end
end

module type Config_intf = sig
  type log_gossip_heard =
    {snark_pool_diff: bool; transaction_pool_diff: bool; new_state: bool}
  [@@deriving make, fields]

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; time_controller: Block_time.Controller.t
    ; addrs_and_ports: Node_addrs_and_ports.t
    ; conf_dir: string
    ; chain_id: string
    ; log_gossip_heard: log_gossip_heard
    ; keypair: Coda_net2.Keypair.t option
    ; peers: Coda_net2.Multiaddr.t list
    ; consensus_local_state: Consensus.Data.Local_state.t }
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Network_intf
  with type snark_pool_diff = Inputs.Snark_pool_diff.t
   and type transaction_pool_diff = Inputs.Transaction_pool_diff.t

include
  Coda_intf.Network_intf
  with type snark_pool_diff = Network_pool.Snark_pool.Resource_pool.Diff.t
   and type transaction_pool_diff =
              Network_pool.Transaction_pool.Resource_pool.Diff.t
