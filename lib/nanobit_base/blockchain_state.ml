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
let of_hlist : (unit, 'ti -> 'ta -> 'd -> 'n -> 's -> unit) H_list.t -> ('ti, 'ta, 'd, 'n, 's) t_ =
  H_list.(fun [ previous_time; target; block_hash; number; strength ] -> { previous_time; target; block_hash; number; strength })

let data_spec =
  let open Data_spec in
  [ Block_time.Unpacked.typ
  ; Target.Unpacked.typ
  ; Digest.Unpacked.typ
  ; Block.Body.Unpacked.typ
  ; Strength.Unpacked.typ
  ]

let typ : (var, value) Typ.t =
  Typ.of_hlistable data_spec
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
  let rate = Bignum.Bigint.(previous_difficulty / difficulty_adjustment_rate) in
  let rate = Bignum.Bigint.max rate Bignum.Bigint.one in
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
      compute_target state.previous_time state.target block.header.time
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
  let seq = 
    List.append 
      (List.init 1000 ~f:(fun i -> (1.))) 
      (List.init 500 ~f:(fun i -> (20.))) 
  in
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
  ;;

  let compute_difficulty prev_time prev_strength time =
    let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
    with_label "compute_difficulty" begin
      let%bind delta =
        with_label "delta" begin
          (* This also checks that time >= prev_time *)
          let%map d = Block_time.diff_checked time prev_time in
          let unpacked = div_pow_2 (Block_time.Span.Unpacked.var_to_bits d) target_time_ms in
          Number.of_bits unpacked
        end
      in 
      let `Two_to_the max_difficulty_drop = max_difficulty_drop in
      let max_difficulty_drop = Number.constant (Field.of_int (Int.pow 2 max_difficulty_drop)) in
      let max_difficulty_drop_plus_one = Number.(max_difficulty_drop + Number.constant (Field.one)) in
      let%bind neg_scale_plus_one = 
        let%bind less = Number.(delta < max_difficulty_drop_plus_one) in
        Number.if_ less
          ~then_:delta
          ~else_:max_difficulty_drop_plus_one
      in
      let%bind prev_strength_unpacked = Strength.unpack_var prev_strength in
      let prev_strength_num = Number.of_bits (Strength.Unpacked.var_to_bits prev_strength_unpacked) in
      let rate_floor = div_pow_2 (Strength.Unpacked.var_to_bits prev_strength_unpacked) difficulty_adjustment_rate in
      let rate_floor = Number.of_bits rate_floor in
      let%bind rate = 
        let%bind is_zero = Number.(rate_floor = (Number.constant Field.zero)) in
        Number.if_ is_zero
          ~then_:(Number.constant Field.one)
          ~else_:rate_floor
      in
      let%bind diff_nonzero = Number.(rate * (neg_scale_plus_one - (constant Field.one))) in
      let%bind new_strength_num =
        let%bind is_zero = Number.(neg_scale_plus_one = (Number.constant Field.zero)) in
        Number.if_ is_zero
          ~then_:Number.(prev_strength_num + rate)
          ~else_:Number.(prev_strength_num - diff_nonzero)
      in
      let%map new_strength_unpacked = Strength.field_var_to_unpacked (Number.to_var new_strength_num) in
      Strength.pack_var new_strength_unpacked
    end
  ;;

  let compute_target prev_time prev_target time =
    with_label "compute_target" begin
      let prev_target_packed = Target.pack_var prev_target in
      let%bind prev_strength_packed = Target.strength prev_target_packed prev_target in
      let%bind new_strength_packed = compute_difficulty prev_time prev_strength_packed time in
      let%bind new_strength_unpacked = Strength.unpack_var new_strength_packed in
      let new_strength_unpacked = Strength.Unpacked.var_to_bits new_strength_unpacked in
      let%bind new_target = 
        Util.floor_divide 
          ~numerator:(`Two_to_the Target.bit_length) 
          new_strength_packed
          new_strength_unpacked
      in 
      Target.field_var_to_unpacked new_target
    end
  ;;

  let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
    if Insecure.check_target
    then return Boolean.true_
    else Target.passes target hash

  let valid_body ~prev body =
    with_label "valid_body" begin
      let%bind { less } =
        Checked.compare ~bit_length:Block.Body.bit_length
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

