(*open Core_kernel
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let target_time_ms = `Two_to_the 13 (* 8.192 seconds *);;
let max_difficulty_drop = `Two_to_the 7 (* 128 *) ;;
let difficulty_adjustment_rate = `Two_to_the 11 (* 2048 *) ;;

(* ============================================================== *)

(* max(1-x, y)
=> -min(x-1, -y)
=> -(min(x, -y+1) - 1)
=> 1 - min(x, -y + 1)*)

let workable_compute_difficulty prev_time prev_strength time =
  let%bind delta =
    let%map diff : Number.t = Block_time.diff time prev_time in
    Number.div_pow_2 diff target_time_ms
  in
  let max_difficulty_drop_plus_one = Number.((of_pow_2 max_difficulty_drop) + one) in
  let%bind neg_scale_plus_one = Number.min delta max_difficulty_drop_plus_one in
  let%bind prev_strength = Strength.to_number prev_strength in
  let%bind rate_floor = Number.div_pow_2 prev_strength difficulty_adjustment_rate in
  let%bind rate = Number.max rate_floor Number.one in
  let%bind rate_scalar, is_positive = 
    Number.if_equal neg_scale_plus_one Number.zero
      ~then_:(return (Number.one, Boolean.true))
      ~else_:(return (Number.Unsafe.(neg_scale_plus_one - one), Boolean.false))
  in
  let%bind diff = Number.(rate_scalar * rate) in
  let%bind new_strength = 
    Boolean.if_ is_positive
      ~then_:Number.(prev_strength + diff)
      ~else_:
        (Number.if_less prev_strength Number.(one + diff)
           ~then_:Number.one
           ~else_:Number.Unsafe.(prev_strength - diff)
        )
  in
  Strength.of_number new_strength

(* ============================================================== *)

let dream_compute_difficulty prev_time prev_strength time =
  let%bind delta =
    let%map diff : Number.t = Block_time.diff time prev_time in
    Number.div_pow_2 diff target_time_ms |> Number.Signed.of_number
  in
  let max_difficulty_drop = Number.(of_pow_2 max_difficulty_drop) |> Number.Signed.of_number in
  let%bind rate_scalar = Number.min Number.Signed.(one - delta) (Number.Signed.of_negative max_difficulty_drop) in
  let%bind prev_strength = Strength.to_number prev_strength >>= Number.Signed.of_number in
  let%bind rate_floor = Number.div_pow_2 prev_strength difficulty_adjustment_rate in
  let%bind rate = Number.max rate_floor Number.one >>= Number.Signed.of_number in
  let%bind diff = Number.Signed.(rate_scalar * rate) in
  let%bind new_strength_signed = Number.Signed.max Number.Signed.(prev_strength + diff) Number.Signed.one in
  let%bind new_strength : Number.t = Number.Signed.assert_positive new_strength_signed in
  Strength.of_number new_strength*)
