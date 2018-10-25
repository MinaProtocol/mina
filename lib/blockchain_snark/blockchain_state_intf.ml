open Core_kernel
open Coda_base
open Snark_params
open Tick

module type S = sig
  module Consensus_mechanism : Consensus.Mechanism.S

  module type Update_intf = sig
    module Checked : sig
      val update :
           Consensus_mechanism.Protocol_state.Hash.var
           * Consensus_mechanism.Protocol_state.var
        -> Consensus_mechanism.Snark_transition.var
        -> ( Consensus_mechanism.Protocol_state.Hash.var
             * Consensus_mechanism.Protocol_state.var
             * [`Success of Boolean.var]
           , _ )
           Checked.t
    end
  end

  module Make_update (T : Transaction_snark.Verification.S) : Update_intf

  module Checked : sig
    val hash :
         Consensus_mechanism.Protocol_state.var
      -> (Consensus_mechanism.Protocol_state.Hash.var, _) Checked.t

    val is_base_hash :
      Consensus_mechanism.Protocol_state.Hash.var -> (Boolean.var, _) Checked.t
  end
end
