open Core_kernel
open Util
open Snark_params
open Tick
open Let_syntax

module Digest = Pedersen.Digest

let difficulty_window = 17

let all_but_last_exn xs = fst (split_last_exn xs)

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

type t = (Block_time.t, Target.t, Digest.t, Block.Body.t, Strength.t) t_
[@@deriving bin_io, sexp]

type var =
  ( Block_time.Unpacked.var
  , Target.Unpacked.var
  , Digest.Packed.var
  , Block.Body.Packed.var
  , Strength.Packed.var
  ) t_

type value =
  ( Block_time.Unpacked.value
  , Target.Unpacked.value
  , Digest.Packed.value
  , Block.Body.Packed.value
  , Strength.Packed.value
  ) t_

let to_hlist { previous_time; target; block_hash; number; strength } = H_list.([ previous_time; target; block_hash; number; strength ])
let of_hlist = H_list.(fun [ previous_time; target; block_hash; number; strength ] -> { previous_time; target; block_hash; number; strength })

let data_spec =
  let open Data_spec in
  [ Block_time.Unpacked.spec
  ; Target.Unpacked.spec
  ; Digest.Packed.spec
  ; Block.Body.Packed.spec
  ; Strength.Packed.spec
  ]

let spec : (var, value) Var_spec.t =
  Var_spec.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let bound_divisor = `Two_to_the 11
let delta_minus_one_max_bits = 7
let target_time_ms = `Two_to_the 13 (* 8.192 seconds *)

let compute_target previous_time (previous_target : Target.t) time =
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
  assert Block_time.(time > previous_time);
  let rate_multiplier = div_pow_2 Bignum.Bigint.(target_max - previous_target) bound_divisor in
  let delta =
    Bignum.Bigint.(
      of_int64 Block_time.(Span.to_ms (diff time previous_time)) / target_time_ms)
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

let zero = update_exn negative_one Block.genesis

let to_bits ({ previous_time; target; block_hash; number; strength } : var) =
  let%map h = Digest.Checked.(unpack block_hash >>| to_bits)
  and n = Block.Body.Checked.(unpack number >>| to_bits)
  and s = Strength.Checked.(unpack strength >>| to_bits)
  in
  Block_time.Checked.to_bits previous_time
  @ Target.Checked.to_bits target
  @ h
  @ n
  @ s

let to_bits_unchecked ({ previous_time; target; block_hash; number; strength } : value) =
  let h = Digest.(Unpacked.to_bits (unpack block_hash)) in
  let n = Block.Body.(Unpacked.to_bits (unpack number)) in
  let s = Strength.(Unpacked.to_bits (unpack strength)) in
  Block_time.Bits.to_bits previous_time
  @ Target.Unpacked.to_bits target
  @ h
  @ n
  @ s

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
    with_label "State.hash" (to_bits t >>= hash_digest)

  let compute_target prev_time prev_target time =
    let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
    let delta_minus_one_max_bits = 7 in
    with_label "compute_target" begin
      let prev_target_n = Number.of_bits (Target.Checked.to_bits prev_target) in
      let%bind rate_multiplier =
        with_label "rate_multiplier" begin
          let%map distance_to_max_target =
            let open Number in
            to_bits (constant (Target.max :> Field.t) - prev_target_n)
          in
          Number.of_bits (div_pow_2 distance_to_max_target bound_divisor)
        end
      in
      let%bind delta =
        with_label "delta" begin
          (* This also checks that time >= prev_time *)
          let%map d = Block_time.diff_checked time prev_time in
          div_pow_2 (Block_time.Span.Checked.to_bits d) target_time_ms
        end
      in
      let%bind delta_is_nonzero, delta_minus_one =
        with_label "delta_is_nonzero, delta_minus_one" begin
          let n = List.length delta in
          assert (n < Field.size_in_bits);
          let d = Checked.pack delta in
          let d_minus_one = Cvar.Infix.(d - Cvar.constant Field.one) in
          let%bind d_minus_one_bits =
            exists (Var_spec.list ~length:n Boolean.spec)
              As_prover.(map (read_var d_minus_one) ~f:(fun x ->
                List.init n ~f:(Bigint.test_bit (Bigint.of_field x))))
          in
          let d_minus_one' = Number.of_bits d_minus_one_bits in
          let%map is_non_zero = Checked.equal d_minus_one (Number.to_var d_minus_one') in
          is_non_zero, d_minus_one'
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
          Checked.if_ delta_is_nonzero
            ~then_:(Number.to_var nonzero_case)
            ~else_:zero_case
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
      let%bind { less } = Util.compare ~bit_length:Block.Body.bit_length prev body in
      Boolean.Assert.is_true less
    end
  ;;

  let update (state : var) (block : Block.Packed.var) =
    with_label "Blockchain.State.update" begin
      let%bind () =
        assert_equal ~label:"previous_block_hash"
          block.header.previous_block_hash state.block_hash
      in
      let%bind () = valid_body ~prev:state.number block.body in
      let target_packed = Target.pack state.target in
      let%bind strength = Target.strength target_packed state.target in
      let%bind block_unpacked = Block.Checked.unpack block in
      let%bind block_hash =
        let bits = Block.Checked.to_bits block_unpacked in
        hash_digest bits
      in
      let%bind meets_target = meets_target target_packed block_hash in
      let time_unpacked = block_unpacked.header.time in
      let%map new_target = compute_target state.previous_time state.target time_unpacked in
      ( { previous_time = time_unpacked
        ; target = new_target
        ; block_hash
        ; number = block.body
        ; strength = Cvar.Infix.(strength + state.strength)
        }
      , `Success meets_target
      )
    end
end

