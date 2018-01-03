open Core_kernel
open Util
open Snark_params

module Extend (Impl : Camlsnark.Snark_intf.S) = struct
  include Impl

  module Snarkable = struct
    module type S = sig
      type var
      type value
      val spec : (var, value) Var_spec.t
    end

    module Bits = struct
      module type S = sig
        module Packed : sig
          type var
          type value
          val spec : (var, value) Var_spec.t
        end

        module Unpacked : sig
          type var = Boolean.var list
          type value
          val spec : (var, value) Var_spec.t

          module Padded : sig
            type var = private Boolean.var list
            type value
            val spec : (var, value) Var_spec.t
          end
        end

        module Checked : sig
          val pad : Unpacked.var -> Unpacked.Padded.var
          val unpack : Packed.var -> (Unpacked.var, _) Checked.t
        end
      end
    end
  end
end

module Make_types (Impl : Snark_intf.S) = struct
  module Digest = Pedersen.Main.Digest.Snarkable(Impl)
  module Time = Block_time.Snarkable(Impl)
  module Span = Block_time.Span.Snarkable(Impl)
  module Target = Target.Snarkable(Impl)
  module Nonce = Nonce.Snarkable(Impl)
  module Strength = Strength.Snarkable(Impl)
  module Block = Block.Snarkable(Impl)(Digest)(Time)(Span)(Target)(Nonce)(Strength)

  module Scalar = Pedersen.Main.Curve.Scalar(Impl)
end

module Main = struct
  module T = Extend(Snark_params.Main)

  include T
  include Make_types(T)

  module Hash_curve =
    Camlsnark.Curves.Edwards.Extend
      (T)
      (Scalar)
      (Pedersen.Main.Curve)

  module Pedersen = Camlsnark.Pedersen.Make(T)(struct
      include Hash_curve
      let cond_add = Hash_curve.Checked.cond_add
    end)

  module Util = Snark_util.Make(T)

  let hash_digest x =
    let open Checked in
    Pedersen.hash x
      ~params:Pedersen_params.t
      ~init:Hash_curve.Checked.identity
    >>| Pedersen.digest

end
module Other = struct
  module T = Extend(Snark_params.Other)
  include T
  include Make_types(T)
end


let () = assert (Main.Field.size_in_bits = Other.Field.size_in_bits)

let step_input () =
  let open Main in
  let open Data_spec in
  [ Digest.Packed.spec (* Self key hash *)
  ; Digest.Packed.spec (* Block header hash *)
  ]

module Wrap = struct
  let step_input_size = Main.Data_spec.size (step_input ())

  open Other

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Other)(Other_curve)(Main_curve)
      (struct let input_size = step_input_size end)

  (* TODO: These numbers are wrong *)
  let step_vk_length = 11324
  let step_vk_size = 38
  let step_vk_spec =
    Var_spec.list ~length:step_vk_size Var_spec.field

  let input_spec =
    Var_spec.list ~length:step_input_size Var_spec.field

  let input () =
    Data_spec.([ step_vk_spec; input_spec ])

  module Prover_state = struct
    type t =
      { vk    : Main_curve.Verification_key.t
      ; proof : Main_curve.Proof.t
      }
  end

  let main verification_key (input : Cvar.t list) =
    let open Let_syntax in
    let%bind v =
      let%bind input =
        List.map ~f:(Checked.unpack ~length:Main_curve.Field.size_in_bits) input
        |> Checked.all
        |> Checked.map ~f:List.concat
      in
      (* TODO: Unpacking here is totally pointless. Edit libsnark
          so we don't have to do this. *)
      let%bind verification_key =
        List.map ~f:(Checked.unpack ~length:Main_curve.Field.size_in_bits) verification_key
        |> Checked.all
        |> Checked.map ~f:List.concat
      in
      Verifier.All_in_one.create ~verification_key ~input
        As_prover.(map get_state ~f:(fun {Prover_state.vk; proof} ->
          { Verifier.All_in_one.verification_key=vk; proof }))
    in
    assert_equal (Verifier.All_in_one.result v :> Cvar.t) (Cvar.constant Field.one)
  ;;
end

module Make_step (M : sig
    open Main

    module State : sig
      type var
      type value
      val spec : (var, value) Var_spec.t

      val is_base_case : var -> (Boolean.var, _) Checked.t
      val hash : var -> (Pedersen.Digest.var, _) Checked.t
    end

    module Update : sig
      type var
      type value
      val spec : (var, value) Var_spec.t

      val apply : var -> State.var -> (State.var, _) Checked.t
    end
  end)
= struct
  open M

  module Prover_state = struct
    type t =
      { self       : bool list
      ; prev_state : State.value
      ; update     : Update.value
      }
    [@@deriving fields]
  end

  open Main
  open Let_syntax

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Main)(Main_curve)(Other_curve)
      (struct let input_size = Other.Data_spec.size (Wrap.input ()) end)

  let input = step_input

  let self_vk_spec =
    Var_spec.list ~length:Wrap.step_vk_length Boolean.spec

  let get spec ~f = store spec As_prover.(map get_state ~f)

  let unhash ~spec ~f ~to_bits h =
    let%bind b = get spec ~f in
    let%bind h' = hash_digest (to_bits b) in
    let%map () = assert_equal h h' in
    b
  ;;

  let main self_hash_packed state_hash =
    let%bind self =
      unhash self_hash_packed ~f:Prover_state.self
        ~spec:self_vk_spec ~to_bits:Fn.id
    in
    let%bind prev_state = get State.spec ~f:Prover_state.prev_state
    and update          = get Update.spec ~f:Prover_state.update
    in
    let%bind next_state = Update.apply update prev_state in
    let%bind h = State.hash next_state in
    assert_equal h state_hash
end

module Step = struct
  module Block0 = Block
  open Main
  open Let_syntax

  module State = struct
    let difficulty_window = 10

    type ('time, 'target, 'digest) t =
      { difficulty_info : ('time * 'target) list
      ; block_hash      : 'digest
      }

(* Someday: It may well be worth using bitcoin's compact nbits for target values since
   targets are quite chunky *)
    type var = (Time.Unpacked.var, Target.Unpacked.var, Pedersen.Digest.var) t
    type value = (Time.Unpacked.value, Target.Unpacked.value, Pedersen.Digest.value) t

    let to_hlist { difficulty_info; block_hash } = H_list.([ difficulty_info; block_hash ])
    let of_hlist = H_list.(fun [ difficulty_info; block_hash ] -> { difficulty_info; block_hash })

    let data_spec =
      let open Data_spec in
      [ Var_spec.(list ~length:difficulty_window (tuple2 Time.Unpacked.spec Target.Unpacked.spec))
      ; Pedersen.Digest.spec
      ]

    let spec : (var, value) Var_spec.t =
      Var_spec.of_hlistable data_spec
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist
        ~value_to_hlist:to_hlist ~value_of_hlist:of_hlist

    let to_bits { difficulty_info; block_hash } =
      let%map bs = Pedersen.Digest.unpack block_hash in
      List.concat_map ~f:(fun (x, y) -> x @ y) difficulty_info @ bs

    let hash (t : var) = to_bits t >>= hash_digest 
  end

  module Update = struct
    type var = Block.Packed.var
    type value = Block.Packed.var
    let spec = Block.Packed.spec

    let all_but_last_exn xs = fst (split_last_exn xs)

    let compute_target _ = failwith "TODO"

    let meets_target _ _ = failwith "TODO"

    let apply (block : var) (state : State.var) =
      let%bind target = compute_target state.difficulty_info in
      let%bind block_unpacked = Block.Checked.unpack block in
      let%bind () =
        let%bind h = hash_digest (Block.Unpacked.to_bits block_unpacked) in
        assert_equal h block.header.body_hash
      in
      let%bind h = hash_digest (Block.Header.Unpacked.to_bits block_unpacked) in
      let%bind () = meets_target block.header target in
      failwith "TODO"
  end

  (*

  open Main

  open Let_syntax

  module Prover_state = struct
    type t =
(*       { block             : Block.Packed.value *)
      { block_unpacked       : Block.Unpacked.value
(*       ; prev_block        : Block.Packed.value *)
      ; prev_header_unpacked : Block.Header.Unpacked.value
      ; prev_proof           : Other.Proof.t
      ; self                 : bool list
      }
    [@@deriving fields]
  end

  let input = step_input

  let self_vk_spec =
    Var_spec.list ~length:Wrap.step_vk_length Boolean.spec

  let hash_digest x =
    Main.Pedersen.hash x
      ~params:Pedersen_params.t
      ~init:Main.Hash_curve.Checked.identity
    >>| Main.Pedersen.digest

  let unhash ~spec ~f ~to_bits h =
    let%bind b = store spec As_prover.(map get_state ~f) in
    let%bind h' = hash_digest (to_bits b) in
    let%map () = assert_equal h h' in
    b
  ;;

  let get_prev_header_unpacked =
    store Block.Header.Unpacked.spec
      As_prover.(map get_state ~f:Prover_state.prev_header_unpacked)
  ;;

  let hash_unpacked bs = hash_digest bs >>= Pedersen.Digest.unpack

  let compute_target _ _ = return (failwith "TODO")

  let construct_next_block (prev_block_header : Block.Header.Unpacked.var)
    : (Block.Unpacked.var, _) Checked.t
    =
    let%bind body =
      store Block.Body.Unpacked.spec 
        As_prover.(map get_state ~f:(fun s -> s.Prover_state.block_unpacked.body))
    in
    let%bind (header : Block.Header.Unpacked.var) =
      let get spec f =
        store spec
          As_prover.(map get_state ~f:(fun s -> f s.Prover_state.block_unpacked.header))
      in
      let module H = Block0.Header in
      let%bind previous_header_hash =
        hash_unpacked (Block.Header.Unpacked.to_bits prev_block_header)
      and body_hash = hash_unpacked body
      and time      = get Time.Unpacked.spec H.time
      and nonce     = get Nonce.Unpacked.spec H.nonce
      in
      let deltas = failwith "TODO" in
      let%map target =
        compute_target prev_block_header.deltas prev_block_header.strength 
      in
      { H.previous_header_hash
      ; body_hash
      ; time
      ; target
      ; nonce
      ; deltas
      ; strength = failwith "TODO"
      }
    in
    return { Block0.body; header }

  let main
        (self_hash_packed : Digest.Packed.var)
        (header_hash_packed : Digest.Packed.var)
    : (unit, Prover_state.t) Checked.t =
    let%bind self =
      unhash self_hash_packed ~f:Prover_state.self
        ~spec:self_vk_spec ~to_bits:Fn.id
    in
    let%bind prev_header_unpacked = get_prev_header_unpacked in
    let%bind block_unpacked = construct_next_block prev_header_unpacked in
    hash_is header_hash_packed (Block.Header.Unpacked.to_bits block_unpacked.header) *)
end
