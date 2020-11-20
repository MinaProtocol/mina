type t

module Affine = struct
  type t =
    (Marlin_plonk_bindings_pasta_fq.t * Marlin_plonk_bindings_pasta_fq.t)
    Marlin_plonk_bindings_types.Or_infinity.t
end

external one : unit -> t = "caml_pasta_vesta_one"

external add : t -> t -> t = "caml_pasta_vesta_add"

external sub : t -> t -> t = "caml_pasta_vesta_sub"

external negate : t -> t = "caml_pasta_vesta_negate"

external double : t -> t = "caml_pasta_vesta_double"

external scale :
  t -> Marlin_plonk_bindings_pasta_fp.t -> t
  = "caml_pasta_vesta_scale"

external random : unit -> t = "caml_pasta_vesta_random"

external rng : int -> t = "caml_pasta_vesta_rng"

external to_affine : t -> Affine.t = "caml_pasta_vesta_to_affine"

external of_affine : Affine.t -> t = "caml_pasta_vesta_of_affine"

external of_affine_coordinates :
  Marlin_plonk_bindings_pasta_fq.t -> Marlin_plonk_bindings_pasta_fq.t -> t
  = "caml_pasta_vesta_of_affine_coordinates"

external endo_base :
  unit -> Marlin_plonk_bindings_pasta_fq.t
  = "caml_pasta_vesta_endo_base"

external endo_scalar :
  unit -> Marlin_plonk_bindings_pasta_fp.t
  = "caml_pasta_vesta_endo_scalar"
