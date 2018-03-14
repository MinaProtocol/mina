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

(* d_{i+1} = max(d_i + max(\frac{d_i}{r}, 1)max(1 - \frac{t_i - t_{i-1}}{\Delta_{target}}, scale_{min}), 1) *)

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
  let scale = Bignum.Bigint.max scale Bignum.Bigint.(-max_difficulty_drop) in
  let rate = Bignum.Bigint.(previous_difficulty / difficulty_adjustment_rate) in
  let rate = Bignum.Bigint.max rate Bignum.Bigint.one in
  let diff = Bignum.Bigint.(rate * scale) in
  Bignum.Bigint.max Bignum.Bigint.(previous_difficulty + diff) (Bignum.Bigint.of_int 1)

let compute_difficulty_x = compute_difficulty

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
        Target.(to_bigint max) / pow (of_int 2) (of_int 1))
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
    with_label "compute_difficulty" begin
      let%bind delta =
        let%bind diff = Block_time.diff_number time prev_time in
        Number.div_pow_2 diff target_time_ms
      in 
      let max_difficulty_drop = Number.of_pow_2 max_difficulty_drop in
      let max_difficulty_drop_plus_one = Number.(max_difficulty_drop + one) in
      let%bind neg_scale_plus_one = Number.min delta max_difficulty_drop_plus_one in
      let%bind prev_strength_num = Strength.packed_to_number prev_strength in
      let%bind rate_floor = Number.div_pow_2 prev_strength_num difficulty_adjustment_rate in
      let%bind rate = Number.max rate_floor Number.one in
      let%bind rate_scalar = 
        let%bind is_zero = Number.(neg_scale_plus_one = zero) in
        Number.if_ is_zero
          ~then_:Number.one
          ~else_:(Number.minus_unsafe neg_scale_plus_one Number.one)
      in
      let%bind diff = Number.mul_unsafe rate rate_scalar in
      let%bind diff = 
        (* TODO need to do this else Number.< throws, how to properly fix that? *)
        let%map diff = Number.to_bits_unsafe diff 64 in
        let diff = List.take diff 64 in
        Number.of_bits diff
      in
      let%bind diff_minus = Number.min diff prev_strength_num in
      let%bind new_strength_num =
        let%bind is_zero = Number.(neg_scale_plus_one = zero) in
        Number.if_ is_zero
          ~then_:(Number.sum_unsafe prev_strength_num diff)
          ~else_:(Number.minus_unsafe prev_strength_num diff_minus)
      in
      let%bind new_strength_num = Number.max new_strength_num Number.one in
      Strength.packed_of_number new_strength_num
    end
  ;;

  let random_n_bit_field_elt n =
    Field.project (List.init n ~f:(fun _ -> Random.bool ()))
  ;;



  let%test_unit "compute_difficulty" = 
    let test prev_strength secs =
      let prev_time =  Block.genesis.header.time in
      let time = Block_time.of_time (Time.add (Block_time.to_time prev_time) (sec secs)) in
      let time_to_field t = Field.of_int (Int64.to_int_exn (Int64.of_float (Time.Span.to_ms (Time.to_span_since_epoch t)))) in
      let prev_time_field = time_to_field (Block_time.to_time prev_time) in
      let time_field = time_to_field (Block_time.to_time time) in

      let ((), new_strength, passed) =
        run_and_check
          (let%bind prev_strength_var = Strength.field_var_to_unpacked (Cvar.constant (Field.of_int prev_strength)) in
           let%bind prev_time_var = Block_time.field_var_to_unpacked (Cvar.constant prev_time_field) in
           let%bind time_var = Block_time.field_var_to_unpacked (Cvar.constant time_field) in
           let%map new_strength = compute_difficulty prev_time_var (Strength.pack_var prev_strength_var) time_var in
           As_prover.(read Strength.Packed.typ new_strength))
          ()
      in
      let new_strength = Bigint.to_bignum_bigint (Bigint.of_field new_strength) in
      let prev_strength_bigint = Bignum.Bigint.of_int_exn prev_strength in
      let new_strength_unchecked = compute_difficulty_x prev_time prev_strength_bigint time in
      printf "%d %f %s %s\n"
        prev_strength
        secs
        (Sexp.to_string_hum ([%sexp_of: Bignum.Bigint.t] new_strength_unchecked))
        (Sexp.to_string_hum ([%sexp_of: Bignum.Bigint.t] new_strength));
      assert passed;
      assert Bignum.Bigint.(new_strength_unchecked = new_strength)
    in
    let strengths = [ 50; 500; 5000 ] in
    let times = [ 0.1; 1.0; 10.0; 20.0; 50.0; 100.0; 1000.0 ] in
    List.iter strengths
      ~f:(fun s -> 
        List.iter times
          ~f:(fun t -> test s t))
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

