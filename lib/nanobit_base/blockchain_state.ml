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

(* Someday: This should really just use bigint arithmetic rather than field arithmetic *)
let compute_target previous_time (previous_target : Target.t) time =
  let delta_minus_one_max_bits = 7 in
  let delta_minus_one_max = Field.(sub (Util.two_to_the delta_minus_one_max_bits) one) in
  let lt_field x y = Bigint.(compare (of_field x) (of_field y)) < 0 in
  let min x y = if lt_field x y then x else y in
  let bound_divisor = Util.two_to_the 11 in
  let target_time_ms = Int64.(pow (of_int 2) (of_int 19)) in
  let previous_target = (previous_target :> Field.t) in
  let rate_multiplier =
    Field.Infix.(((Target.max :> Field.t) - previous_target) / bound_divisor)
  in
  assert Block_time.(time > previous_time);
  let delta =
    Int64.(
      to_int_exn
        (Block_time.(Span.to_ms (diff time previous_time))
         / target_time_ms))
    |> Field.of_int
  in
  Target.of_field begin
    if Field.(equal delta zero)
    then begin
      if lt_field previous_target rate_multiplier
      then Field.one
      else Field.sub previous_target rate_multiplier
    end else begin
      let gamma =
        min Field.(sub delta one) delta_minus_one_max
      in
      Field.Infix.(previous_target + rate_multiplier * gamma)
    end
  end
;;

let update_exn (state : value) (block : Block.t) =
  let block_hash = Block.hash block in
  assert (Target.meets_target_unchecked state.target ~hash:block_hash);
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
  let previous_time = Block_time.of_time Core.Time.epoch in
  let target : Target.Unpacked.value = Target.max in
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

  module Number : sig
    type t

    val (+)      : t -> t -> t
    val (-)      : t -> t -> t
    val ( * )    : t -> t -> (t, _) Checked.t
    val constant : Field.t -> t

    val (<) : t -> t -> (Boolean.var, _) Checked.t

    val to_var : t -> Cvar.t

    val of_bits : Boolean.var list -> t
    val to_bits : t -> (Boolean.var list, _) Checked.t

    val clamp_to_n_bits : t -> int -> (t, _) Checked.t
  end = struct
    type t =
      { upper_bound : Bignum.Bigint.t
      ; lower_bound : Bignum.Bigint.t
      ; var         : Cvar.t
      ; bits        : Boolean.var list option
      }

    let pow2 n = Bignum.Bigint.(pow (of_int 2) (of_int n))

    let bigint_num_bits =
      let rec go acc i =
        if Bignum.Bigint.(acc = zero)
        then i
        else go (Bignum.Bigint.shift_right acc 1) (i + 1)
      in
      fun n -> go n 0
    ;;

    let to_bits { var; bits; upper_bound; lower_bound = _ } =
      let length = bigint_num_bits upper_bound in
      with_label "Number.to_bits" begin
        match bits with
        | Some bs -> return (List.take bs length)
        | None -> Checked.unpack var ~length
      end
    ;;

    let of_bits bs =
      let n = List.length bs in
      assert (n < Field.size_in_bits);
      { upper_bound = Bignum.Bigint.(pow2 n - one)
      ; lower_bound = Bignum.Bigint.zero
      ; var = Checked.pack bs
      ; bits = Some bs
      }

    let clamp_to_n_bits t n =
      assert (n < Field.size_in_bits);
      with_label "Number.clamp_to_n_bits" begin
        let k = pow2 n in
        if Bignum.Bigint.(t.upper_bound < k)
        then return t
        else
          let%bind bs = to_bits t in
          let bs' = List.take bs n in
          let g = Checked.pack bs' in
          let%bind fits = Checked.equal t.var g in
          let%map r =
            Checked.if_ fits
              ~then_:g
              ~else_:(Cvar.constant Field.(sub (Util.two_to_the n) one))
          in
          { upper_bound = Bignum.Bigint.(k - one)
          ; lower_bound = t.lower_bound
          ; var = r
          ; bits = None
          }
      end
    ;;

    let (<) x y =
      let open Bignum.Bigint in
      (*
       x [ ]
       y     [ ]

       x     [ ]
       y [ ] 
      *)
      with_label "Number.(<)" begin
        if x.upper_bound < y.lower_bound
        then return Boolean.true_
        else if x.lower_bound > y.upper_bound
        then return Boolean.false_
        else
          let bit_length =
            Int.max (bigint_num_bits x.upper_bound) (bigint_num_bits y.upper_bound)
          in
          let%map { less; _ } = Util.compare ~bit_length x.var y.var in
          less
      end
    ;;

    let to_var { var; _ } = var

    let bigint_of_tick_bigint n =
      let rec go i two_to_the_i acc =
        if i = Field.size_in_bits
        then acc
        else
          let acc' =
            if Bigint.test_bit n i
            then Bignum.Bigint.(acc + two_to_the_i)
            else acc
          in
          go (i + 1) Bignum.Bigint.(two_to_the_i + two_to_the_i) acc'
      in
      go 0 Bignum.Bigint.one Bignum.Bigint.zero

    let constant x =
      let tick_n = Bigint.of_field x in
      let n = bigint_of_tick_bigint tick_n in
      { upper_bound = n
      ; lower_bound = n
      ; var = Cvar.constant x
      ; bits =
          Some 
            (List.init (bigint_num_bits n) ~f:(fun i ->
              Boolean.var_of_value (Tick.Bigint.test_bit tick_n i)))
      }

    let field_size = bigint_of_tick_bigint Tick_curve.field_size

    let (+) x y =
      let open Bignum.Bigint in
      let upper_bound = x.upper_bound + y.upper_bound in
      if upper_bound < field_size
      then
        { upper_bound
        ; lower_bound = x.lower_bound + y.lower_bound
        ; var = Cvar.add x.var y.var
        ; bits = None
        }
      else failwith "Number.+: Potential overflow: "

    let (-) x y =
      let open Bignum.Bigint in
      (* x_upper_bound >= x >= x_lower_bound >= y_upper_bound >= y >= y_lower_bound *)
      if x.lower_bound >= y.upper_bound
      then
        { upper_bound = x.upper_bound - y.lower_bound
        ; lower_bound = x.lower_bound - y.upper_bound
        ; var = Cvar.sub x.var y.var
        ; bits = None
        }
      else
        failwithf "Number.-: Potential underflow (%s < %s)"
          (to_string x.lower_bound) (to_string y.upper_bound) ()

    let ( * ) x y =
      let open Bignum.Bigint in
      with_label "Number.(*)" begin
        let upper_bound = x.upper_bound * y.upper_bound in
        if upper_bound < field_size
        then
          let%map var = Checked.mul x.var y.var in
          { upper_bound
          ; lower_bound = x.lower_bound + y.lower_bound
          ; var 
          ; bits = None
          }
        else failwith "Number.+: Potential overflow"
      end
  end

  (* TODO: Don't call these assertions every time *)
  let compute_target prev_time prev_target time =
    let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
    let bound_divisor = `Two_to_the 11 in
    let target_time_ms = `Two_to_the 19 in
    let delta_minus_one_max_bits = 7 in
    let () =
      let `Two_to_the bd = bound_divisor in
      let rate_multiplier_bit_length = Target.bit_length - bd in
      let gamma_bit_length = delta_minus_one_max_bits in
      (* This is so rate_multiplier * gamma is safe. *)
      assert (gamma_bit_length + rate_multiplier_bit_length <= Field.size_in_bits - 1);
      (* ((max - prev_target) >> bd) * gamma
          < ((max - prev_target) >> bd) << gamma_bit_length
          < max - prev_target [assuming gamma_bit_length < bd]
          so the addition
          prev_target + ((max - prev_target) >> bd) * gamma
          is safe
      *)
      assert (gamma_bit_length < bd);
    in
    let prev_target_packed = Checked.pack (Target.Checked.to_bits prev_target) in
    let%bind distance_to_max_target =
      Target.var_to_unpacked
        (Cvar.sub
            (Cvar.constant (Target.max :> Field.t))
            prev_target_packed)
    in
    (* Has [Target.bit_length - bound_divisor] many bits *)
    let rate_multiplier =
      Checked.pack
        (div_pow_2 (Target.Checked.to_bits distance_to_max_target)
            bound_divisor)
    in
    let%bind delta =
      (* This also checks that time >= prev_time *)
      let%map d = Block_time.diff_checked time prev_time in
      div_pow_2 (Block_time.Span.Checked.to_bits d) target_time_ms
    in
    let%bind delta_is_nonzero, delta_minus_one, delta_minus_one_bits =
      let n = List.length delta in
      assert (n < Field.size_in_bits);
      let d = Checked.pack delta in
      let d_minus_one = Cvar.Infix.(d - Cvar.constant Field.one) in
      let%bind d_minus_one_bits =
        exists (Var_spec.list ~length:n Boolean.spec)
          As_prover.(map (read_var d_minus_one) ~f:(fun x ->
            List.init n ~f:(Bigint.test_bit (Bigint.of_field x))))
      in
      let d_minus_one' = Checked.pack d_minus_one_bits in
      let%map is_non_zero = Checked.equal d_minus_one d_minus_one' in
      is_non_zero, d_minus_one', d_minus_one_bits
    in
    let%bind gamma =
      let g = Checked.pack (List.take delta_minus_one_bits delta_minus_one_max_bits) in
      let%bind fits = Checked.equal delta_minus_one g in
      Checked.if_ fits
        ~then_:g
        ~else_:(Cvar.constant Field.(sub (Util.two_to_the delta_minus_one_max_bits) one))
    in
    let%bind nonzero_case =
      let%map rg = Checked.mul rate_multiplier gamma in
      Cvar.add prev_target_packed rg
    in
    let%bind zero_case =
      (* This could be more efficient *)
      let%bind { less; _ } =
        Util.compare ~bit_length:Target.bit_length prev_target_packed rate_multiplier
      in
      Checked.if_ less
        ~then_:(Cvar.constant Field.one)
        ~else_:(Cvar.sub prev_target_packed rate_multiplier)
    in
    let%bind res =
      Checked.if_ delta_is_nonzero
        ~then_:nonzero_case
        ~else_:zero_case
    in
    Target.var_to_unpacked res
  (*
      if delta = 0 (* Block was fast, target should go down. *)
      then prev_target - rate_multiplier * 1
      else if delta > 0 then
        (* Block was slow, make target higher *)
        prev_target + rate_multiplier * max (delta - 1) 99 *)

  (* TODO: Don't call these assertions every time *)
  let compute_target prev_time prev_target time =
    let div_pow_2 bits (`Two_to_the k) = List.drop bits k in
    let bound_divisor = `Two_to_the 11 in
    let target_time_ms = `Two_to_the 19 in
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

  let compute_target _ _ _ = Target.var_to_unpacked (Cvar.constant (Target.max :> Field.t))

  let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
    if Insecure.check_target
    then return Boolean.true_
    else
      failwith "TODO"

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
      let%bind meets_target = Target.passes target_packed block_hash in
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

