open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Snark_params
open Fold_lib

module Verification
    (Consensus_mechanism : Consensus.S) (Wrap : sig
        val key : Tock.Verification_key.t

        val key_to_bool_list : Tock.Verification_key.t -> bool list
    end) =
struct
  let instance_hash =
    let self = Wrap.key_to_bool_list Wrap.key in
    fun state ->
      Tick.Pedersen.digest_fold Hash_prefix.transition_system_snark
        Fold.(
          group3 ~default:false (of_list self)
          +> State_hash.fold (Consensus_mechanism.Protocol_state.hash state))

  let verify_wrap state proof =
    Tock.verify proof Wrap.key
      Tock.Data_spec.[Wrap_input.typ]
      (Wrap_input.of_tick_field (instance_hash state))
end
