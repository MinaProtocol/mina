open Core_kernel
open Nanobit_base
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let difficulty_window = 17

let all_but_last_exn xs = fst (split_last_exn xs)

module Hash = State_hash

module Stable = struct
  module V1 = struct
    (* Someday: It may well be worth using bitcoin's compact nbits for target values since
      targets are quite chunky *)
    type ('target, 'state_hash, 'ledger_hash, 'strength, 'time) t_ =
      { next_difficulty     : 'target
      ; previous_state_hash : 'state_hash
      ; ledger_hash         : 'ledger_hash
      ; strength            : 'strength
      ; timestamp           : 'time
      }
    [@@deriving bin_io, sexp, fields, eq]

    type t = (Target.Stable.V1.t, State_hash.Stable.V1.t, Ledger_hash.Stable.V1.t, Strength.Stable.V1.t, Block_time.Stable.V1.t) t_
    [@@deriving bin_io, sexp, eq]
  end
end

include Stable.V1

type var =
  ( Target.Unpacked.var
  , State_hash.var
  , Ledger_hash.var
  , Strength.Unpacked.var
  , Block_time.Unpacked.var
  ) t_

type value =
  ( Target.Unpacked.value
  , State_hash.t
  , Ledger_hash.t
  , Strength.Unpacked.value
  , Block_time.Unpacked.value
  ) t_

let to_hlist { next_difficulty; previous_state_hash; ledger_hash; strength; timestamp } =
  H_list.([ next_difficulty; previous_state_hash; ledger_hash; strength; timestamp ])
let of_hlist : (unit, 'ta -> 'sh -> 'lh -> 'st -> 'ti -> unit) H_list.t -> ('ta, 'sh, 'lh, 'st, 'ti) t_ =
  H_list.(fun [ next_difficulty; previous_state_hash; ledger_hash; strength; timestamp ] -> { next_difficulty; previous_state_hash; ledger_hash; strength; timestamp })

let data_spec =
  let open Data_spec in
  [ Target.Unpacked.typ
  ; State_hash.typ
  ; Ledger_hash.typ
  ; Strength.Unpacked.typ
  ; Block_time.Unpacked.typ
  ]

let typ : (var, value) Typ.t =
  Typ.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let bound_divisor = `Two_to_the 11
let delta_minus_one_max_bits = 7
let target_time_ms = `Two_to_the 13 (* 8.192 seconds *)

let compute_target timestamp (previous_target : Target.t) time =
  let target_time_ms =
    let `Two_to_the k = target_time_ms in
    Bignum.Bigint.(pow (of_int 2) (of_int k))
  in
  let target_max = Target.(to_bigint max) in
  let delta_minus_one_max =
    Bignum.Bigint.(pow (of_int 2) (of_int delta_minus_one_max_bits) - one)
  in
  let div_pow_2 x (`Two_to_the k) = Bignum.Bigint.shift_right x k in
  let previous_target = Target.to_bigint previous_target in
  assert Block_time.(time > timestamp);
  let rate_multiplier = div_pow_2 Bignum.Bigint.(target_max - previous_target) bound_divisor in
  let delta =
    Bignum.Bigint.(
      of_int64 Block_time.(Span.to_ms (diff time timestamp)) / target_time_ms)
  in
  let open Bignum.Bigint in
  Target.of_bigint begin
    if delta = zero
    then begin
      if previous_target < rate_multiplier
      then one
      else previous_target - rate_multiplier
    end else begin
      let gamma =
        min (delta - one) delta_minus_one_max
      in
      previous_target + rate_multiplier * gamma
    end
  end
;;

let negative_one =
  let next_difficulty : Target.Unpacked.value =
    Target.of_bigint
      Bignum.Bigint.(
        Target.(to_bigint max) / pow (of_int 2) (of_int 4))
  in
  let timestamp =
    Block_time.of_time
      (Time.sub (Block_time.to_time Block.genesis.header.time) (Time.Span.second))
  in
  { next_difficulty
  ; previous_state_hash = State_hash.of_hash Pedersen.zero_hash
  ; ledger_hash = Ledger.merkle_root (Ledger.create ())
  ; strength = Strength.zero
  ; timestamp
  }

let to_bits ({ next_difficulty; previous_state_hash; ledger_hash; strength; timestamp } : var) =
  let%map ledger_hash_bits = Ledger_hash.var_to_bits ledger_hash
  and previous_state_hash_bits = State_hash.var_to_bits previous_state_hash
  in
  Target.Unpacked.var_to_bits next_difficulty
  @ previous_state_hash_bits
  @ ledger_hash_bits
  @ Strength.Unpacked.var_to_bits strength
  @ Block_time.Unpacked.var_to_bits timestamp

let to_bits_unchecked ({ next_difficulty; previous_state_hash; ledger_hash; strength; timestamp } : value) =
  Target.Bits.to_bits next_difficulty
  @ State_hash.to_bits previous_state_hash
  @ Ledger_hash.to_bits ledger_hash
  @ Strength.Bits.to_bits strength
  @ Block_time.Bits.to_bits timestamp

let hash t =
  let s = Pedersen.State.create Pedersen.params in
  Pedersen.State.update_fold s
    (List.fold_left (to_bits_unchecked t))
  |> Pedersen.State.digest
  |> State_hash.of_hash

let update_unchecked : value -> Block.t -> value =
  fun state block ->
    let next_difficulty =
      compute_target state.timestamp state.next_difficulty
        block.header.time
    in
    { next_difficulty
    ; previous_state_hash = hash state
    ; ledger_hash = block.body.target_hash
    ; strength = Strength.increase state.strength ~by:state.next_difficulty
    ; timestamp = block.header.time
    }

let zero = update_unchecked negative_one Block.genesis
let zero_hash = hash zero

let bit_length =
  let add bit_length acc _field = acc + bit_length in
  Stable.V1.Fields_of_t_.fold zero ~init:0
    ~next_difficulty:(add Target.bit_length)
    ~previous_state_hash:(add State_hash.bit_length)
    ~ledger_hash:(add Ledger_hash.bit_length)
    ~strength:(add Strength.bit_length)
    ~timestamp:(fun acc _ _ -> acc + Block_time.bit_length)

module Make_update (T : Transaction_snark.S) = struct
  let update_exn state (block : Block.t) =
    assert
      (Transaction_snark.create
        ~source:state.ledger_hash
        ~target:block.body.target_hash
        ~proof_type:Merge
        ~fee_excess:Currency.Amount.Signed.zero
        ~proof:block.body.proof
        |> T.verify);
    let hash =
      Pedersen.hash_fold Pedersen.params
        (List.fold
           (to_bits_unchecked state @ Nonce.Bits.to_bits block.header.nonce))
    in
    assert (Target.meets_target_unchecked state.next_difficulty ~hash);
    update_unchecked state block

  module Checked = struct
    let compute_target prev_time prev_target time =
      let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
      let delta_minus_one_max_bits = 7 in
      with_label __LOC__ begin
        let prev_target_n = Number.of_bits (Target.Unpacked.var_to_bits prev_target) in
        let%bind rate_multiplier =
          with_label __LOC__ begin
            let%map distance_to_max_target =
              let open Number in
              to_bits (constant (Target.max :> Field.t) - prev_target_n)
            in
            Number.of_bits (div_pow_2 distance_to_max_target bound_divisor)
          end
        in
        let%bind delta =
          with_label __LOC__ begin
            (* This also checks that time >= prev_time *)
            let%map d = Block_time.diff_checked time prev_time in
            div_pow_2 (Block_time.Span.Unpacked.var_to_bits d) target_time_ms
          end
        in
        let%bind delta_is_zero, delta_minus_one =
          with_label __LOC__ begin
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
          with_label __LOC__ begin
            let open Number in
            let%bind gamma = clamp_to_n_bits delta_minus_one delta_minus_one_max_bits in
            let%map rg = rate_multiplier * gamma in
            prev_target_n + rg
          end
        in
        let%bind zero_case =
          (* This could be more efficient *)
          with_label __LOC__ begin
            let%bind less = Number.(prev_target_n < rate_multiplier) in
            Checked.if_ less
              ~then_:(Cvar.constant Field.one)
              ~else_:(Cvar.sub (Number.to_var prev_target_n) (Number.to_var rate_multiplier))
          end
        in
        let%bind res =
          with_label __LOC__ begin
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

    module Prover_state = struct
      type t =
        { transaction_snark : Tock.Proof.t
        }
      [@@deriving fields]
    end

    let update ((previous_state_hash, previous_state) : State_hash.var * var) (block : Block.var)
      : (State_hash.var * var * [ `Success of Boolean.var ], _) Tick.Checked.t
      =
      with_label __LOC__ begin
        let%bind good_body =
          T.verify_complete_merge
            previous_state.ledger_hash block.body.target_hash
            (As_prover.return block.body.proof)
        in
        let difficulty = previous_state.next_difficulty in
        let difficulty_packed = Target.pack_var difficulty in
        let time = block.header.time in
        let%bind new_difficulty = compute_target previous_state.timestamp difficulty time in
        let%bind new_strength =
          Strength.increase_checked (Strength.pack_var previous_state.strength)
            ~by:(difficulty_packed, difficulty)
          >>= Strength.unpack_var
        in
        let new_state =
          { next_difficulty = new_difficulty
          ; previous_state_hash
          ; ledger_hash = block.body.target_hash
          ; strength = new_strength
          ; timestamp = time
          }
        in
        let%bind state_bits = to_bits new_state in
        let%bind state_hash =
          Pedersen_hash.hash state_bits
            ~params:Pedersen.params
            ~init:(0, Tick.Hash_curve.Checked.identity)
        in
        let%bind pow_hash =
          Pedersen_hash.hash (Nonce.Unpacked.var_to_bits block.header.nonce)
            ~params:Pedersen.params
            ~init:(List.length state_bits, state_hash)
          >>| Pedersen_hash.digest
        in
        let%bind meets_target = meets_target difficulty_packed pow_hash in
        let%map success = Boolean.(good_body && meets_target) in
        (State_hash.var_of_hash_packed (Pedersen_hash.digest state_hash), new_state, `Success success)
      end
    ;;
  end
end

module Checked = struct
  let is_base_hash h =
    with_label __LOC__
      (Checked.equal (Cvar.constant (zero_hash :> Field.t))
         (State_hash.var_to_hash_packed h))

  let hash (t : var) =
    with_label __LOC__ (to_bits t >>= hash_digest >>| State_hash.var_of_hash_packed)
end

