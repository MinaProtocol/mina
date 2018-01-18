open Core_kernel
open Util
open Snark_params

let bitstring xs =
  String.of_char_list (List.map xs ~f:(fun b -> if b then '1' else '0'))

module Make_types (Impl : Snark_intf.S) = struct
  module Digest = Snark_params.Main.Pedersen.Digest.Snarkable(Impl)
  module Time = Block_time.Snarkable(Impl)
  module Target = Digest
  module Nonce = Nonce.Snarkable(Impl)
  module Strength = Strength.Snarkable(Impl)
  module Block = Block.Snarkable(Impl)(Digest)(Time)(Nonce)(Strength)

  module Scalar = Snark_params.Main.Pedersen.Curve.Scalar(Impl)
end

module Main = struct
  include Snark_params.Main
  include Make_types(Snark_params.Main)

  module Hash_curve =
    Camlsnark.Curves.Edwards.Extend
      (Snark_params.Main)
      (Scalar)
      (Snark_params.Main.Pedersen.Curve)

  module Pedersen_hash = Camlsnark.Pedersen.Make(Snark_params.Main)(struct
      include Hash_curve
      let cond_add = Checked.cond_add
    end)

  module Util = Snark_util.Make(Snark_params.Main)

  let hash_digest x =
    let open Checked in
    Pedersen_hash.hash x
      ~params:Pedersen.params
      ~init:Hash_curve.Checked.identity
    >>| Pedersen_hash.digest

end

module Other = struct
  module T = Extend(Snark_params.Other)
  include T
  include Make_types(T)
end

module Block0 = Block

module System = struct
  open Main
  open Let_syntax

  let compute_target_unchecked _ = Field.(negate one)

  let all_but_last_exn xs = fst (split_last_exn xs)

  module State = struct
    let difficulty_window = 17

    type ('time, 'target, 'digest) t =
      (* Someday: To avoid hashing a big list it might be better to make this a blockchain
         (that is verified as things go). *)
      { difficulty_info : ('time * 'target) list
      ; block_hash      : 'digest
      }

    let fold_bits { difficulty_info; block_hash } ~init ~f =
      let init =
        List.fold difficulty_info ~init ~f:(fun init (time, target) -> 
          let init = Time.Unpacked.fold time ~init ~f in
          let init = Target.Unpacked.fold target ~init ~f in
          init)
      in
      Digest.Unpacked.fold block_hash ~init ~f
    ;;

(* Someday: It may well be worth using bitcoin's compact nbits for target values since
   targets are quite chunky *)
    type var = (Time.Unpacked.var, Target.Unpacked.var, Digest.Packed.var) t
    type value = (Time.Unpacked.value, Target.Unpacked.value, Digest.Packed.value) t

    let sexp_of_value ({ difficulty_info; block_hash } : value) : Sexp.t =
      let field_to_string x = bitstring (Field.unpack x) in
      List
        [ List
            [ Atom "difficulty_info"
            ; [%sexp_of: (Block_time.t * string) list]
                (List.map difficulty_info ~f:(fun (x, y) -> (x, field_to_string y)))
            ]
        ; List [ Atom "block_hash"; [%sexp_of: string] (field_to_string block_hash) ]
        ]
    ;;

    let value_to_string v = Sexp.to_string_hum (sexp_of_value v)

    let to_hlist { difficulty_info; block_hash } = H_list.([ difficulty_info; block_hash ])
    let of_hlist = H_list.(fun [ difficulty_info; block_hash ] -> { difficulty_info; block_hash })

    let data_spec =
      let open Data_spec in
      [ Var_spec.(list ~length:difficulty_window (tuple2 Time.Unpacked.spec Target.Unpacked.spec))
      ; Digest.Packed.spec
      ]

    let spec : (var, value) Var_spec.t =
      Var_spec.of_hlistable data_spec
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let apply_unchecked (block : Block0.t) state =
      let target = compute_target_unchecked state.difficulty_info in
      let block_hash = Block0.hash block in
      { difficulty_info =
          (block.header.time, target)
          :: all_but_last_exn state.difficulty_info
      ; block_hash
      }

    let state_negative_one : value =
      let time = Block_time.of_time Core.Time.epoch in
      let target : Target.Unpacked.value =
        Target.unpack (Field.of_int (-1))
      in
      { difficulty_info =
          List.init difficulty_window ~f:(fun _ -> (time, target))
      ; block_hash = Block0.(hash genesis)
      }

    let state_zero  =
      apply_unchecked Block0.genesis state_negative_one

    let to_bits { difficulty_info; block_hash } =
      let%map bs = Digest.Checked.unpack block_hash in
      List.concat_map ~f:(fun (x, y) -> x @ y) difficulty_info
      @ bs

    let to_bits_unchecked ({ difficulty_info; block_hash } : value) =
      let bs = Digest.Unpacked.to_bits (Digest.unpack block_hash) in
      List.concat_map difficulty_info ~f:(fun (x, y) ->
        Block_time.Bits.to_bits x @ Target.Unpacked.to_bits y)
      @ bs

    let hash_unchecked t =
      let s = Pedersen.State.create Pedersen.params in
      Pedersen.State.update_fold s
        (List.fold_left (to_bits_unchecked t));
      Pedersen.State.digest s

    let base_hash = hash_unchecked state_zero

    let is_base_hash h = Checked.equal (Cvar.constant base_hash) h

    let hash (t : var) = to_bits t >>= hash_digest
  end

  module Update = struct
    type var = Block.Packed.var
    type value = Block.Packed.value
    let spec : (var, value) Var_spec.t = Block.Packed.spec

    (* TODO: A subsequent PR will replace this with the actual difficulty calculation *)
    let compute_target _ =
      return (Cvar.constant Field.(negate one))

    let apply_unchecked = State.apply_unchecked

    let meets_target (target : Target.Packed.var) (hash : Digest.Packed.var) =
      with_label "meets_target" begin
        let%map { less } = Util.compare ~bit_length:Field.size_in_bits target hash in
        less
      end

    let apply (block : var) (state : State.var) =
      with_label "apply" begin
        let%bind () =
          assert_equal ~label:"previous_block_hash"
            block.header.previous_block_hash state.block_hash
        in
        let%bind target = compute_target state.difficulty_info in
        let%bind block_unpacked = Block.Checked.unpack block in
        let%bind block_hash =
          let bits = Block.Unpacked.to_bits block_unpacked in
          hash_digest bits
        in
        let%bind meets_target = meets_target target block_hash in
        let%map target_unpacked = Target.Checked.unpack target in
        ( { State.difficulty_info =
              (block_unpacked.header.time, target_unpacked)
              :: all_but_last_exn state.difficulty_info
          ; block_hash
          }
        , `Success meets_target
        )
      end
  end
end

module Transition =
  Transition_system.Make
    (struct
      module Main = Main.Digest
      module Other = Other.Digest
    end)
    (struct let hash = Main.hash_digest end)
    (System)

module Step = Transition.Step
module Wrap = Transition.Wrap

let base_hash =
  Transition.instance_hash System.State.state_zero

let base_proof =
  let dummy_proof =
    let open Other in
    let input = Data_spec.[] in
    let main =
      let one = Cvar.constant Field.one in
      assert_equal one one
    in
    let keypair = generate_keypair input main in
    prove (Keypair.pk keypair) input () main
  in
  Main.prove Step.proving_key (Step.input ())
    { Step.Prover_state.prev_proof = dummy_proof
    ; wrap_vk  = Wrap.verification_key
    ; prev_state = System.State.state_negative_one
    ; update = Block.genesis
    }
    Step.main
    base_hash

let () =
  assert
    (Main.verify base_proof Step.verification_key
       (Step.input ()) base_hash)
;;

