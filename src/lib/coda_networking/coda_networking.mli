open Coda_base
open Coda_transition

val refused_answer_query_string : string

module type Base_inputs_intf = Coda_intf.Inputs_intf

module type Inputs_intf = sig
  include Base_inputs_intf

  module Snark_pool_diff : sig
    type t [@@deriving sexp, to_yojson]

    module Stable :
      sig
        module V1 : sig
          type t [@@deriving sexp, bin_io, to_yojson, version]
        end
      end
      with type V1.t = t
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
  type gossip_config

  type t =
    { logger: Logger.t
    ; trust_system: Trust_system.t
    ; gossip_net_params: gossip_config
    ; time_controller: Block_time.Controller.t
    ; consensus_local_state: Consensus.Data.Local_state.t }
end

module Make (Inputs : Inputs_intf) :
  Coda_intf.Network_intf
  with type external_transition := Inputs.External_transition.t
   and type transaction_snark_scan_state := Inputs.Staged_ledger.Scan_state.t
   and type snark_pool_diff = Inputs.Snark_pool_diff.t
   and type transaction_pool_diff = Inputs.Transaction_pool_diff.t

include
  Coda_intf.Network_intf
  with type external_transition := External_transition.t
   and type transaction_snark_scan_state := Staged_ledger.Scan_state.t
   and type snark_pool_diff = Network_pool.Snark_pool.Resource_pool.Diff.t
   and type transaction_pool_diff =
              Network_pool.Transaction_pool.Resource_pool.Diff.t
