open Core_kernel
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let difficulty_window = 17

let all_but_last_exn xs = fst (split_last_exn xs)

module Stable = struct
  module V1 = struct
    (* Someday: It may well be worth using bitcoin's compact nbits for target values since
      targets are quite chunky *)
    type ('time, 'target, 'digest, 'number, 'strength) t_ =
      { previous_time : 'time
      ; target        : 'target
      ; block_hash    : 'digest
      ; number        : 'number
      ; strength      : 'strength
      }
    [@@deriving bin_io, sexp]

    type t = (Block_time.Stable.V1.t, Target.Stable.V1.t, Digest.t, Block.Body.Stable.V1.t, Strength.Stable.V1.t) t_
    [@@deriving bin_io, sexp]
  end
end

include Stable.V1

type var =
  ( Block_time.Unpacked.var
  , Target.Unpacked.var
  , Digest.Unpacked.var
  , Block.Body.Unpacked.var
  , Strength.Unpacked.var
  ) t_

type value =
  ( Block_time.Unpacked.value
  , Target.Unpacked.value
  , Digest.Unpacked.value
  , Block.Body.Unpacked.value
  , Strength.Unpacked.value
  ) t_

let to_hlist { previous_time; target; block_hash; number; strength } = H_list.([ previous_time; target; block_hash; number; strength ])
let of_hlist = H_list.(fun [ previous_time; target; block_hash; number; strength ] -> { previous_time; target; block_hash; number; strength })

let data_spec =
  let open Data_spec in
  [ Block_time.Unpacked.spec
  ; Target.Unpacked.spec
  ; Digest.Unpacked.spec
  ; Block.Body.Unpacked.spec
  ; Strength.Unpacked.spec
  ]

let spec : (var, value) Var_spec.t =
  Var_spec.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let target_to_strength target = 
  let strength = Bignum.Bigint.((Target.to_bigint Target.max) / target) in
  strength

let strength_to_target strength = 
  let target = Bignum.Bigint.((Target.to_bigint Target.max) / strength) in
  Target.of_bigint target

(* homestead difficulty calculation
 * https://github.com/ethereum/EIPs/blob/master/EIPS/eip-2.md
 * block_target = parent_target + parent_target //_ceil difficulty_adjustment_rate * max(1 - (block_timestamp_ms - parent_timestamp_ms) //_floor target_time_ms, -max_difficulty_drop)
 *)

let target_time_ms = `Two_to_the 13 (* 8.192 seconds *);;
let max_difficulty_drop = `Two_to_the 7 (* 128 *) ;;
let difficulty_adjustment_rate = `Two_to_the 11 (* 2048 *) ;;

let compute_difficulty previous_time previous_difficulty time = 
  let pow2_bigint n =
    let `Two_to_the k = n in
    Bignum.Bigint.(pow (of_int 2) (of_int k))
  in
  let target_time_ms = pow2_bigint target_time_ms in
  let max_difficulty_drop = pow2_bigint max_difficulty_drop in
  let difficulty_adjustment_rate = pow2_bigint difficulty_adjustment_rate in
  let time_diff = Time.diff (Block_time.to_time time) (Block_time.to_time previous_time) in
  let time_diff_ms = Bignum.Bigint.of_int (Int.of_float (Time.Span.to_ms time_diff)) in

  let scale = Bignum.Bigint.(Bignum.Bigint.one - (time_diff_ms / target_time_ms)) in
  printf "%s\n" (Sexp.to_string_hum ([%sexp_of: Bignum.Bigint.t] scale));
  let scale = Bignum.Bigint.max scale Bignum.Bigint.(-max_difficulty_drop) in
  let div_ceil n d = Bignum.Bigint.((n + d - Bignum.Bigint.one) / d) in
  let rate = div_ceil previous_difficulty difficulty_adjustment_rate in
  let diff = Bignum.Bigint.(rate * scale) in
  Bignum.Bigint.(previous_difficulty + diff)

let compute_target previous_time previous_target time = 
  strength_to_target (compute_difficulty previous_time (target_to_strength (Target.to_bigint previous_target)) time)

let update_exn : value -> Block.t -> value =
  let genesis_hash = Block.(hash genesis) in
  fun state block ->
    let block_hash = Block.hash block in
    (if not Field.(equal block_hash genesis_hash)
    then assert(Target.meets_target_unchecked state.target ~hash:block_hash));
    assert Int64.(block.body > state.number);
    let new_target =
      state.target (*compute_target state.previous_time state.target block.header.time*)
    in
    let strength = Target.strength_unchecked state.target in
    { previous_time = block.header.time
    ; target = new_target
    ; block_hash
    ; number = block.body
    ; strength = Field.add strength state.strength
    }

let negative_one : value =
  let previous_time =
    Block_time.of_time
      (Time.sub (Block_time.to_time Block.genesis.header.time) (Time.Span.second))
  in
  let target : Target.Unpacked.value =
    Target.of_bigint
      Bignum.Bigint.(
        Target.(to_bigint max) / pow (of_int 2) (of_int 5))
  in
  { previous_time
  ; target
  ; block_hash = Block.genesis.header.previous_block_hash
  ; number = Int64.of_int 0
  ; strength = Strength.zero
  }

let%test "compute_difficulty_stable" = 
  let init = strength_to_target (Bignum.Bigint.of_int 1024) in
  let time = Block_time.to_time Block.genesis.header.time in
  let seq = List.concat [ (List.init 1000 ~f:(fun i -> (1.))); (List.init 500 ~f:(fun i -> (20.))) ] in
  printf "\n";
  let result = List.fold_until ~init:(time, init) seq ~f:(fun (time, target) diff ->
    let new_time = Time.add time (sec diff) in
    let new_target = strength_to_target (compute_difficulty (Block_time.of_time time) (target_to_strength (Target.to_bigint target)) (Block_time.of_time new_time)) in
    let strength_float = Float.of_int (Bignum.Bigint.to_int_exn (target_to_strength (Target.to_bigint target))) in
    let new_strength_float = Float.of_int (Bignum.Bigint.to_int_exn (target_to_strength (Target.to_bigint new_target))) in
    let diff = Float.max (strength_float /. new_strength_float) (new_strength_float /. strength_float) in
    printf "%s %s %f\n" 
      (Sexp.to_string_hum ([%sexp_of: Bignum.Bigint.t] (Target.to_bigint new_target)))
      (Sexp.to_string_hum ([%sexp_of: Bignum.Bigint.t] (target_to_strength (Target.to_bigint new_target))))
      diff;
    if diff > 1.1
    then Stop "target unstable"
    else Continue (new_time, new_target))
  in
  match result with 
  | Stopped_early _ -> false
  | Finished _ -> true

let zero = update_exn negative_one Block.genesis

let to_bits ({ previous_time; target; block_hash; number; strength } : var) =
  Block_time.Unpacked.var_to_bits previous_time
  @ Target.Unpacked.var_to_bits target
  @ Digest.Unpacked.var_to_bits block_hash
  @ Block.Body.Unpacked.var_to_bits number
  @ Strength.Unpacked.var_to_bits strength

let to_bits_unchecked ({ previous_time; target; block_hash; number; strength } : value) =
  Block_time.Bits.to_bits previous_time
  @ Target.Bits.to_bits target
  @ Digest.Bits.to_bits block_hash
  @ Block.Body.Bits.to_bits number
  @ Strength.Bits.to_bits strength

let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s
    (List.fold_left (to_bits_unchecked t))
  |> Pedersen.State.digest

let zero_hash = hash zero

module Checked = struct
  let is_base_hash h =
    with_label "State.is_base_hash"
      (Checked.equal (Cvar.constant zero_hash) h)

  let hash (t : var) =
    with_label "State.hash" (hash_digest (to_bits t))

  let compute_target prev_time prev_target time =
    let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
    let delta_minus_one_max_bits = 7 in
    with_label "compute_target" begin
      let prev_target_n = Number.of_bits (Target.Unpacked.var_to_bits prev_target) in
      let%bind rate_multiplier =
        with_label "rate_multiplier" begin
          let%map distance_to_max_target =
            let open Number in
            to_bits (constant (Target.max :> Field.t) - prev_target_n)
          in
          Number.of_bits (div_pow_2 distance_to_max_target max_difficulty_drop)
        end
      in
      let%bind delta =
        with_label "delta" begin
          (* This also checks that time >= prev_time *)
          let%map d = Block_time.diff_checked time prev_time in
          div_pow_2 (Block_time.Span.Unpacked.var_to_bits d) target_time_ms
        end
      in
      let%bind delta_is_zero, delta_minus_one =
        with_label "delta_is_nonzero, delta_minus_one" begin
          (* There used to be a trickier version of this code that did this in 2 fewer constraints,
             might be worth going back to if there is ever a reason. *)
          let n = List.length delta in
          let d = Checked.pack delta in
          let%bind delta_is_zero = Checked.equal d (Cvar.constant Field.zero) in
          let%map delta_minus_one =
            Checked.if_ delta_is_zero
              ~then_:(Cvar.constant Field.zero)
              ~else_:Cvar.(Infix.(d - constant Field.one))
            (* We convert to bits here because we will in [clamp_to_n_bits] anyway, and
               this gives us the upper bound we need for multiplying with [rate_multiplier]. *)
            >>= Checked.unpack ~length:n
            >>| Number.of_bits
          in
          delta_is_zero, delta_minus_one
        end
      in
      let%bind nonzero_case =
        with_label "nonzero_case" begin
          let open Number in
          let%bind gamma = clamp_to_n_bits delta_minus_one delta_minus_one_max_bits in
          let%map rg = rate_multiplier * gamma in
          prev_target_n + rg
        end
      in
      let%bind zero_case =
        (* This could be more efficient *)
        with_label "zero_case" begin
          let%bind less = Number.(prev_target_n < rate_multiplier) in
          Checked.if_ less
            ~then_:(Cvar.constant Field.one)
            ~else_:(Cvar.sub (Number.to_var prev_target_n) (Number.to_var rate_multiplier))
        end
      in
      let%bind res =
        with_label "res" begin
          Checked.if_ delta_is_zero
            ~then_:zero_case
            ~else_:(Number.to_var nonzero_case)
        end
      in
      Target.var_to_unpacked res
    end
  ;;

  let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
    if Insecure.check_target
    then return Boolean.true_
    else Target.passes target hash

  let valid_body ~prev body =
    with_label "valid_body" begin
      let%bind { less } =
        Util.compare ~bit_length:Block.Body.bit_length
          (Block.Body.pack_var prev) (Block.Body.pack_var body)
      in
      Boolean.Assert.is_true less
    end
  ;;

  let update (state : var) (block : Block.var) =
    with_label "Blockchain.State.update" begin
      let%bind () =
        assert_equal ~label:"previous_block_hash"
(* TODO-soon: There should be a "proof-of-work" var type which is a Target.bit_length
   long string so we can use pack rather than project here. *)
          (Digest.project_var block.header.previous_block_hash)
          (Digest.project_var state.block_hash)
      in
      let%bind () = valid_body ~prev:state.number block.body in
      let target_packed = Target.pack_var state.target in
      let%bind strength = Target.strength target_packed state.target in
      let%bind block_hash =
        let bits = Block.var_to_bits block in
        hash_digest bits
      in
      let%bind block_hash_bits = Digest.choose_preimage_var block_hash in
      let%bind meets_target = meets_target target_packed block_hash in
      let time = block.header.time in
      let%bind new_target = compute_target state.previous_time state.target time in
      let%map strength' =
        Strength.unpack_var Cvar.Infix.(strength + Strength.pack_var state.strength)
      in
      ( { previous_time = time
        ; target = new_target
        ; block_hash = block_hash_bits
        ; number = block.body
        ; strength = strength'
        }
      , `Success meets_target
      )
    end
end

