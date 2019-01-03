open Core

(* This module implements a snarky function for the Groth--Maller 2017 verifier. *)
module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Impl
  open Let_syntax

  module Verification_key = struct
    type ('g1, 'g2, 'fqk) t_ =
      { query_base: 'g1
      ; query: 'g1 list
      ; h: 'g2
      ; g_alpha: 'g1
      ; h_beta: 'g2
      ; g_gamma: 'g1
      ; h_gamma: 'g2
      ; g_alpha_h_beta: 'fqk }

    type ('a, 'b, 'c) vk = ('a, 'b, 'c) t_

    module Precomputation = struct
      type t = {h_gamma: G2_precomputation.t; h: G2_precomputation.t}

      let create (vk : (_, _, _) vk) =
        let%map h_gamma = G2_precomputation.create vk.h_gamma
        and h = G2_precomputation.create vk.h in
        {h_gamma; h}
    end
  end

  module Proof = struct
    type ('g1, 'g2) t_ = {a: 'g1; b: 'g2; c: 'g1}

    let to_hlist {a; b; c} = Snarky.H_list.[a; b; c]

    let of_hlist :
        (unit, 'a -> 'b -> 'a -> unit) Snarky.H_list.t -> ('a, 'b) t_ =
      function
      | [a; b; c] -> {a; b; c}

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
        ~f:(fun acc (g, input) ->
          let%bind term = G1.scale g input in
          Shifted.add acc term )
      >>= Shifted.unshift_nonzero
    in
    let%bind test1 =
      let%bind a_g_alpha = G1.add_exn a vk.g_alpha in
      let%bind b_h_beta =
        G2.add_exn b vk.h_beta >>= G2_precomputation.create
      in
      group_miller_loop
        (* This is where we use [one : G2.t] rather than gamma. *)
        [ (Pos, G1_precomputation.create a_g_alpha, b_h_beta)
        ; (Neg, G1_precomputation.create acc, vk_precomp.h_gamma)
        ; (Neg, G1_precomputation.create c, vk_precomp.h) ]
      >>= final_exponentiation
      >>= Fqk.equal vk.g_alpha_h_beta
    and test2 =
      let%bind b = G2_precomputation.create b in
      group_miller_loop
        [ (Pos, G1_precomputation.create a, vk_precomp.h_gamma)
        ; (Neg, G1_precomputation.create vk.g_gamma, b) ]
      >>= final_exponentiation >>= Fqk.equal Fqk.one
    in
    Boolean.(test1 && test2)
end
