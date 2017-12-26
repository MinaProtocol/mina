open Core_kernel

module Extend (Impl : Camlsnark.Snark_intf.S) : Snark_intf.S = struct
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
  module Digest = Pedersen.Digest.Snarkable(Impl)
  module Time = Block_time.Snarkable(Impl)
  module Span = Block_time.Span.Snarkable(Impl)
  module Target = Target.Snarkable(Impl)
  module Nonce = Nonce.Snarkable(Impl)
  module Strength = Strength.Snarkable(Impl)
  module Block = Block.Snarkable(Impl)(Digest)(Time)(Span)(Target)(Nonce)(Strength)

  module Pedersen = Camlsnark.Pedersen.Make(Impl)(Pedersen.Curve)
end

module Main = struct
  module T = Extend(Snark_params.Main)
  include T
  include Make_types(T)
end
module Other = struct
  module T = Extend(Snark_params.Other)
  include T
  include Make_types(T)
end


module Other = Camlsnark.Snark.Make(Other_curve)

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

  let keypair = generate_keypair (input ()) main

  let vk = Keypair.vk keypair
  let pk = Keypair.pk keypair
end

module Step = struct
  open Main

  module Prover_state = struct
    type t =
      { block      : Block.Packed.value
      ; prev_block : Block.Packed.value
      ; prev_proof : Other.Proof.t
      ; self       : bool list
      }
    [@@deriving fields]
  end

  module Verifier =
end
