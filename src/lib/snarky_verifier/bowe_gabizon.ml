open Core
open Groth_bowe_gabizon_common

(* This module implements a snarky function for the BG verifier. *)
module type Inputs_intf = sig
  include Inputs_intf

  val hash :
       ?message:Impl.Boolean.var array
    -> a:G1.t
    -> b:G2.t
    -> c:G1.t
    -> delta_prime:G2.t
    -> (G1.t, _) Impl.Checked.t
end

module Make (Inputs : Inputs_intf) = struct
  open Inputs
  open Impl
  open Let_syntax
  module Verification_key = Make_verification_key (Inputs)

  module Proof = struct
    type ('g1, 'g2) t_ = {a: 'g1; b: 'g2; c: 'g1; delta_prime: 'g2; z: 'g1}
    [@@deriving sexp]

    let to_hlist {a; b; c; delta_prime; z} =
      Snarky.H_list.[a; b; c; delta_prime; z]

    let of_hlist :
           (unit, 'a -> 'b -> 'a -> 'b -> 'a -> unit) Snarky.H_list.t
        -> ('a, 'b) t_ = function
      | [a; b; c; delta_prime; z] ->
          {a; b; c; delta_prime; z}

    let typ =
      Typ.of_hlistable
        Data_spec.[G1.typ; G2.typ; G1.typ; G2.typ; G1.typ]
        ~var_to_hlist:to_hlist ~var_of_hlist:of_hlist ~value_to_hlist:to_hlist
        ~value_of_hlist:of_hlist
  end

  let verify ?message (vk : (_, _, _) Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) inputs
      {Proof.a; b; c; delta_prime; z} =
    let%bind acc =
      let%bind (module Shifted) = G1.Shifted.create () in
      let%bind init = Shifted.(add zero vk.query_base) in
      Checked.List.fold (List.zip_exn vk.query inputs) ~init
        ~f:(fun acc (g, input) -> G1.scale (module Shifted) g input ~init:acc
      )
      >>= Shifted.unshift_nonzero
    in
    let%bind delta_prime_pc = G2_precomputation.create delta_prime in
    let%bind test1 =
      let%bind b = G2_precomputation.create b in
      batch_miller_loop
        [ ( Neg
          , G1_precomputation.create acc
          , G2_precomputation.create_constant G2.Unchecked.one )
        ; (Neg, G1_precomputation.create c, delta_prime_pc)
        ; (Pos, G1_precomputation.create a, b) ]
      >>= final_exponentiation >>= Fqk.equal vk.alpha_beta
    and test2 =
      let%bind ys = hash ?message ~a ~b ~c ~delta_prime in
      batch_miller_loop
        [ (Pos, G1_precomputation.create ys, delta_prime_pc)
        ; (Neg, G1_precomputation.create z, vk_precomp.delta) ]
      >>= final_exponentiation >>= Fqk.equal Fqk.one
    in
    Boolean.(test1 && test2)
end
