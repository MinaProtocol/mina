open Core
open Groth_bowe_gabizon_common

(* This module implements a snarky function for the gammaless Groth16 verifier. *)

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax
  module Verification_key = Make_verification_key (Inputs)

  module Proof = struct
    type ('g1, 'g2) t_ = {a: 'g1; b: 'g2; c: 'g1} [@@deriving sexp]

    let to_hlist {a; b; c} = Snarky.H_list.[a; b; c]

    let of_hlist :
        (unit, 'a -> 'b -> 'a -> unit) Snarky.H_list.t -> ('a, 'b) t_ =
      function
      | [a; b; c] ->
          {a; b; c}

    let typ =
      Typ.of_hlistable
        Data_spec.[G1.typ; G2.typ; G1.typ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  let verify (vk : (_, _, _) Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) inputs {Proof.a; b; c} =
    let%bind acc =
      let%bind (module Shifted) = G1.Shifted.create () in
      let%bind init = Shifted.(add zero vk.query_base) in
      Checked.List.fold (List.zip_exn vk.query inputs) ~init
        ~f:(fun acc (g, input) -> G1.scale (module Shifted) g input ~init:acc
      )
      >>= Shifted.unshift_nonzero
    in
    let%bind test =
      let%bind b = G2_precomputation.create b in
      batch_miller_loop
        (* This is where we use [one : G2.t] rather than gamma. *)
        [ ( Neg
          , G1_precomputation.create acc
          , G2_precomputation.create_constant G2.Unchecked.one )
        ; (Neg, G1_precomputation.create c, vk_precomp.delta)
        ; (Pos, G1_precomputation.create a, b) ]
      >>= final_exponentiation
    in
    Fqk.equal test vk.alpha_beta
end
