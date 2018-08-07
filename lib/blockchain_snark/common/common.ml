open Core

module Blockchain_state = struct
  open Nanobit_base
  include Blockchain_state

  let bound_divisor = `Two_to_the 11

  let delta_minus_one_max_bits = 7

  (** 8.192 seconds *)
  let target_time_ms = `Two_to_the 13

  let compute_target timestamp (previous_target: Target.t) time =
    let target_time_ms =
      let (`Two_to_the k) = target_time_ms in
      Bignum_bigint.(pow (of_int 2) (of_int k))
    in
    let target_max = Target.(to_bigint max) in
    let delta_minus_one_max =
      Bignum_bigint.(pow (of_int 2) (of_int delta_minus_one_max_bits) - one)
    in
    let div_pow_2 x (`Two_to_the k) = Bignum_bigint.shift_right x k in
    let previous_target = Target.to_bigint previous_target in
    assert (Block_time.(time > timestamp)) ;
    let rate_multiplier =
      div_pow_2 Bignum_bigint.(target_max - previous_target) bound_divisor
    in
    let delta =
      let open Bignum_bigint in
      of_int64 Block_time.(Span.to_ms (diff time timestamp)) / target_time_ms
    in
    let open Bignum_bigint in
    Target.of_bigint
      ( if delta = zero then
          if previous_target < rate_multiplier then one
          else previous_target - rate_multiplier
      else
        let gamma = min (delta - one) delta_minus_one_max in
        previous_target + (rate_multiplier * gamma) )

  let update_unchecked : Blockchain_state.t -> Block.t -> Blockchain_state.t =
   fun state block ->
    let next_difficulty =
      compute_target state.timestamp state.next_difficulty block.header.time
    in
    { next_difficulty
    ; previous_state_hash= hash state
    ; ledger_builder_hash= block.body.ledger_builder_hash
    ; ledger_hash= block.body.target_hash
    ; strength= Strength.increase state.strength ~by:state.next_difficulty
    ; timestamp= block.header.time
    ; signer_public_key= state.signer_public_key }
end
