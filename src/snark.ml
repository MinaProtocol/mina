open Core_kernel

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

module Step = struct

  module Block0 = Block

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

  module Verifier =
    Camlsnark.Verifier_gadget.Make(Main)(Main_curve)(Other_curve)
      (struct let input_size = Other.Data_spec.size (Wrap.input ()) end)

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

  let hash_is h b =
    let%bind h' = hash_digest b in
    assert_equal h' h
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
    hash_is header_hash_packed (Block.Header.Unpacked.to_bits block_unpacked.header)
end
