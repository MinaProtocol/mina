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
    [@@deriving hlist]

    let typ ~input_size =
      let spec =
        Data_spec.
          [ G1.typ
          ; Typ.list ~length:input_size G1.typ
          ; G2.typ
          ; G1.typ
          ; G2.typ
          ; G1.typ
          ; G2.typ
          ; Fqk.typ ]
      in
      Typ.of_hlistable spec ~var_to_hlist:t__to_hlist ~var_of_hlist:t__of_hlist
        ~value_to_hlist:t__to_hlist ~value_of_hlist:t__of_hlist

    include Summary.Make (Inputs)

    let summary_length_in_bits ~twist_extension_degree ~input_size =
      summary_length_in_bits ~twist_extension_degree
        ~g1_count:(1 + input_size + 2)
        ~g2_count:3 ~gt_count:1

    let summary_input
        { g_alpha
        ; g_gamma
        ; query_base
        ; query
        ; h
        ; h_beta
        ; h_gamma
        ; g_alpha_h_beta } =
      { Summary.Input.g1s= g_alpha :: g_gamma :: query_base :: query
      ; g2s= [h; h_beta; h_gamma]
      ; gts= [g_alpha_h_beta] }

    type ('a, 'b, 'c) vk = ('a, 'b, 'c) t_

    module Precomputation = struct
      type t = {h_gamma: G2_precomputation.t; h: G2_precomputation.t}

      let create (vk : (_, _, _) vk) =
        let%map h_gamma = G2_precomputation.create vk.h_gamma
        and h = G2_precomputation.create vk.h in
        {h_gamma; h}

      let create_constant (vk : (_, _, _) vk) =
        let h_gamma = G2_precomputation.create_constant vk.h_gamma
        and h = G2_precomputation.create_constant vk.h in
        {h_gamma; h}
    end
  end

  module Proof = struct
    type ('g1, 'g2) t_ = {a: 'g1; b: 'g2; c: 'g1} [@@deriving hlist]

    let typ =
      Typ.of_hlistable
        Data_spec.[G1.typ; G2.typ; G1.typ]
        ~var_to_hlist:t__to_hlist ~var_of_hlist:t__of_hlist
        ~value_to_hlist:t__to_hlist ~value_of_hlist:t__of_hlist
  end

  let verify (vk : (_, _, _) Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) inputs {Proof.a; b; c} =
    let%bind (module G1_shifted) = G1.Shifted.create () in
    let%bind (module G2_shifted) = G2.Shifted.create () in
    let%bind acc =
      let%bind init = G1_shifted.(add zero vk.query_base) in
      Checked.List.fold (List.zip_exn vk.query inputs) ~init
        ~f:(fun acc (g, input) ->
          G1.scale (module G1_shifted) g input ~init:acc )
      >>= G1_shifted.unshift_nonzero
    in
    let%bind test1 =
      let%bind a_g_alpha =
        G1_shifted.(add zero a >>= Fn.flip add vk.g_alpha >>= unshift_nonzero)
      in
      let%bind b_h_beta =
        G2_shifted.(add zero b >>= Fn.flip add vk.h_beta >>= unshift_nonzero)
        >>= G2_precomputation.create
      in
      batch_miller_loop
        [ (Pos, G1_precomputation.create a_g_alpha, b_h_beta)
        ; (Neg, G1_precomputation.create acc, vk_precomp.h_gamma)
        ; (Neg, G1_precomputation.create c, vk_precomp.h) ]
      >>= final_exponentiation
      >>= Fqk.equal vk.g_alpha_h_beta
    and test2 =
      let%bind b = G2_precomputation.create b in
      batch_miller_loop
        [ (Pos, G1_precomputation.create a, vk_precomp.h_gamma)
        ; (Neg, G1_precomputation.create vk.g_gamma, b) ]
      >>= final_exponentiation >>= Fqk.equal Fqk.one
    in
    Boolean.(test1 && test2)
end
