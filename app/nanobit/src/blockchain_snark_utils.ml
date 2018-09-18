open Core
open Async
open Coda_base
open Util
open Blockchain_snark
open Snark_params
open Fold_lib

module Verification
    (Consensus_mechanism : Consensus.Mechanism.S) (Wrap : sig
        val key : Tock.Verification_key.t

        val key_to_bool_list : Tock.Verification_key.t -> bool list

        val input :
             unit
          -> ( 'a
             , 'b
             , Tock.Field.var -> 'a
             , Tock.Field.t -> 'b )
             Tock.Data_spec.t
    end) =
struct
  let instance_hash =
    let self = Wrap.key_to_bool_list Wrap.key in
    fun state ->
      Tick.Pedersen.digest_fold Hash_prefix.transition_system_snark
        Fold.(
          group3 ~default:false (of_list self)
          +> State_hash.fold (Consensus_mechanism.Protocol_state.hash state))

  let embed (x: Tick.Field.t) : Tock.Field.t =
    let n = Tick.Bigint.of_field x in
    let rec go pt acc i =
      if i = Tick.Field.size_in_bits then acc
      else
        go (Tock.Field.add pt pt)
          (if Tick.Bigint.test_bit n i then Tock.Field.add pt acc else acc)
          (i + 1)
    in
    go Tock.Field.one Tock.Field.zero 0

  let verify_wrap state proof =
    Tock.verify proof Wrap.key (Wrap.input ()) (embed (instance_hash state))
end
