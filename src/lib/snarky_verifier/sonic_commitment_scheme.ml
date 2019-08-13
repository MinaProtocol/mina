open Core

module Make (Inputs : Inputs.S_run) (Scalar_field : sig
    type t

    val unpack : t -> bool list

    val sub : t -> t -> t

    val zero : t

    val one : t
  end) = struct
  open Inputs
  open Impl

  module Verification_key = struct
    type ('g1, 'g2) t_ =
      { g: 'g1
      ; h: 'g2
      ; h_alpha: 'g2
      ; h_alpha_x: 'g2 }
    
    type ('a, 'b) vk = ('a, 'b) t_

    module Precomputation = struct
      type t = { g: G1_precomputation.t
               ; h: G2_precomputation.t
               ; h_alpha: G2_precomputation.t
               ; h_alpha_x: G2_precomputation.t }

      let create (vk : (_, _) vk) =
        let g = G1_precomputation.create vk.g in
        let h = G2_precomputation.create vk.h in
        let h_alpha = G2_precomputation.create vk.h_alpha in
        let h_alpha_x = G2_precomputation.create vk.h_alpha_x in
        {g; h; h_alpha; h_alpha_x}
    end
  end

  let unpack_full a =
    Bitstring_lib.Bitstring.Lsb_first.of_list (List.map ~f:Boolean.var_of_value (Scalar_field.unpack a))
  
  let pc_v (vk : _ Verification_key.t_)
      (vk_precomp : Verification_key.Precomputation.t) commitment z (v, w) : Boolean.var =
    final_exponentiation
      (batch_miller_loop
        [ (Pos, G1_precomputation.create w, vk_precomp.h_alpha_x)
        ; ( Pos
          , G1_precomputation.create (G1.add_exn
              (G1.scale vk.g Scalar_field.(unpack_full (sub v one)) ~init:vk.g)
              (G1.scale w Scalar_field.(unpack_full (sub (sub zero z) one)) ~init:w))
          , vk_precomp.h_alpha)
        ; (Neg, G1_precomputation.create commitment, vk_precomp.h) ])
    |> Fqk.(equal_var one)
end

