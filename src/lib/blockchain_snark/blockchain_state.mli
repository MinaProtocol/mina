open Coda_base
open Snark_params
open Tick

module type Update_intf = sig
  module Checked : sig
    val update :
         State_hash.var * Consensus.Protocol_state.var
      -> Consensus.Snark_transition.var
      -> ( State_hash.var
           * Consensus.Protocol_state.var
           * [`Success of Boolean.var]
         , _ )
         Checked.t
  end
end

module Make_update (T : Transaction_snark.Verification.S) : Update_intf

module Checked : sig
  val hash :
    Consensus.Protocol_state.var -> (State_hash.var, _) Checked.t

  val is_base_hash : State_hash.var -> (Boolean.var, _) Checked.t
end
