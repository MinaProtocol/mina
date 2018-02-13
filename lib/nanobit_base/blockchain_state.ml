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
  { difficulty_info : ('time * 'target) list
  ; block_hash      : 'digest
  ; number          : 'number
  ; strength        : 'strength
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

let to_hlist { difficulty_info; block_hash; number; strength } = H_list.([ difficulty_info; block_hash; number; strength ])
let of_hlist = H_list.(fun [ difficulty_info; block_hash; number; strength ] -> { difficulty_info; block_hash; number; strength })

let data_spec =
  let open Data_spec in
  [ Var_spec.(
      list ~length:difficulty_window
        (tuple2 Block_time.Unpacked.spec Target.Unpacked.spec))
  ; Digest.Packed.spec
  ; Block.Body.Packed.spec
  ; Strength.Packed.spec
  ]

let spec : (var, value) Var_spec.t =
  Var_spec.of_hlistable data_spec
    ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
    ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

let compute_target_unchecked _ : Target.t = Target.max

let compute_target = compute_target_unchecked

let update_exn (state : value) (block : Block.t) =
  let target = compute_target_unchecked state.difficulty_info in
  let block_hash = Block.hash block in
  assert (Target.meets_target_unchecked target ~hash:block_hash);
  let strength = Target.strength_unchecked target in
  assert Int64.(block.body > state.number);
  { difficulty_info =
      (block.header.time, target)
      :: all_but_last_exn state.difficulty_info
  ; block_hash
  ; number = block.body
  ; strength = Field.add strength state.strength
  }

let negative_one : value =
  let time = Block_time.of_time Core.Time.epoch in
  let target : Target.Unpacked.value = Target.max in
  { difficulty_info =
      List.init difficulty_window ~f:(fun _ -> (time, target))
  ; block_hash = Block.genesis.header.previous_block_hash
  ; number = Int64.of_int 0
  ; strength = Strength.zero
  }

let zero = update_exn negative_one Block.genesis

let to_bits ({ difficulty_info; block_hash; number; strength } : var) =
  let%map h = Digest.Checked.(unpack block_hash >>| to_bits)
  and n = Block.Body.Checked.(unpack number >>| to_bits)
  and s = Strength.Checked.(unpack strength >>| to_bits)
  in
  List.concat_map difficulty_info ~f:(fun (x, y) ->
    Block_time.Checked.to_bits x @ Target.Checked.to_bits y)
  @ h
  @ n
  @ s

let to_bits_unchecked ({ difficulty_info; block_hash; number; strength } : value) =
  let h = Digest.(Unpacked.to_bits (unpack block_hash)) in
  let n = Block.Body.(Unpacked.to_bits (unpack number)) in
  let s = Strength.(Unpacked.to_bits (unpack strength)) in
  List.concat_map difficulty_info ~f:(fun (x, y) ->
    Block_time.Bits.to_bits x @ Target.Unpacked.to_bits y)
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

  (* TODO: A subsequent PR will replace this with the actual difficulty calculation *)
  let compute_target _ = return Target.(constant max)

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
      let%bind target = compute_target state.difficulty_info in
      let%bind target_unpacked = Target.Checked.unpack target in
      let%bind strength = Target.strength target target_unpacked in
      let%bind block_unpacked = Block.Checked.unpack block in
      let%bind block_hash =
        let bits = Block.Checked.to_bits block_unpacked in
        hash_digest bits
      in
      let%map meets_target = meets_target target block_hash in
      ( { difficulty_info =
            (block_unpacked.header.time, target_unpacked)
            :: all_but_last_exn state.difficulty_info
        ; block_hash
        ; number = block.body
        ; strength = Cvar.Infix.(strength + state.strength)
        }
      , `Success meets_target
      )
    end
end

