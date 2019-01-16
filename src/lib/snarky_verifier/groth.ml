open Core

(* This module implements a snarky function for the gammaless Groth16 verifier. *)
module Make (Inputs : Inputs.S) = struct
  open Inputs
  open Impl
  open Let_syntax

  module Verification_key = struct
    type ('g1, 'g2, 'fqk) t_ =
      {query_base: 'g1; query: 'g1 list; delta: 'g2; alpha_beta: 'fqk}

    include Summary.Make (Inputs)

    let summary_length_in_bits ~twist_extension_degree ~input_size =
      summary_length_in_bits ~twist_extension_degree ~g1_count:(input_size + 1)
        ~g2_count:1 ~gt_count:1

    let summary_input {query_base; query; delta; alpha_beta} =
      {Summary.Input.g1s= query_base :: query; g2s= [delta]; gts= [alpha_beta]}

    type ('a, 'b, 'c) vk = ('a, 'b, 'c) t_

    module Precomputation = struct
      type t = {delta: G2_precomputation.t}

      let create (vk : (_, _, _) vk) =
        let%map delta = G2_precomputation.create vk.delta in
        {delta}

      let create_constant (vk : (_, _, _) vk) =
        {delta= G2_precomputation.create_constant vk.delta}
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
