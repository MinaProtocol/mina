(* open Core

(* This module implements a snarky function for the gammaless Groth16 verifier. *)
module Make (Inputs : Inputs.S_run) = struct
  open Inputs
  open Impl

  module Verification_key = struct
    type 'g2 t_ =
      { h: 'g2
      ; h_alpha: 'g2
      ; h_alpha_x: 'g2 }

    type 'a vk = 'a t_

    module Precomputation = struct
      type t = {h: G2_precomputation.t; h_alpha: G2_precomputation.t; h_alpha_x: G2_precomputation.t}

      let create (vk : _ vk) =
        let h = G2_precomputation.create vk.h in
        let h_alpha = G2_precomputation.create vk.h_alpha in
        let h_alpha_x = G2_precomputation.create vk.h_alpha_x in
        {h; h_alpha; h_alpha_x}
    end
  end

  module Hsc_proof = struct
    type ('g1, 'g2, 'fr) t_ =
      { hsc_s: 'g1 list
      ; hsc_w: ('fr * 'g1) list
      ; hsc_q: ('fr * 'g1) list
      ; hsc_qz: 'g1
      ; hsc_c: 'g1
      ; hsc_u: 'fr
      ; hsc_z: 'fr }
  end

  let pc_v (vk : _ Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) commitment z (v, w) : Boolean.var =
    final_exponentiation
      (batch_miller_loop
        [ (Pos, G1_precomputation.create w, vk_precomp.h_alpha_x)
        ; ( Pos
          , G1_precomputation.create (G1.add_exn
              (G1.scale G1.one (Fr.to_bigint v))
              (G1.scale w (Fr.to_bigint (Fr.negate z))))
          , vk_precomp.h_alpha)
        ; (Neg, G1_precomputation.create commitment, vk_precomp.h) ])
    |> Fqk.(equal one)
  
  let hsc_v (vk : (_, _, _) Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) ys s_poly (proof : Hsc_proof.t_) : Boolean.var =
    let sz = eval_on_x_y proof.hsc_u proof.hsc_z s_poly in
    Checked.List.fold ~f:Boolean.( && ) ~init:true
      ( pc_v vk vk_precomp proof.hsc_c proof.hsc_z (sz, proof.hsc_qz)
        :: List.map2_exn proof.hsc_s proof.hsc_w ~f:(fun sj (wsj, wj) ->
              pc_v vk vk_precomp sj proof.hsc_u (wsj, wj))
      @ List.map2_exn ys proof.hsc_q ~f:(fun yj (qsj, qj) ->
            pc_v vk vk_precomp proof.hsc_c yj (qsj, qj)) )

end *)
