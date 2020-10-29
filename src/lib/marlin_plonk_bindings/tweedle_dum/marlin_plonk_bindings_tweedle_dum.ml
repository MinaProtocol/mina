type t

module Affine = struct
  type t =
    (Marlin_plonk_bindings_tweedle_fp.t * Marlin_plonk_bindings_tweedle_fp.t)
    Marlin_plonk_bindings_types.Or_infinite.t
end

external one : unit -> t = "caml_tweedle_dum_one"

external add : t -> t -> t = "caml_tweedle_dum_add"

external sub : t -> t -> t = "caml_tweedle_dum_sub"

external negate : t -> t = "caml_tweedle_dum_negate"

external double : t -> t = "caml_tweedle_dum_double"

external scale :
  t -> Marlin_plonk_bindings_tweedle_fq.t -> t
  = "caml_tweedle_dum_scale"

external random : unit -> t = "caml_tweedle_dum_random"

external rng : int -> t = "caml_tweedle_dum_rng"

external to_affine : t -> Affine.t = "caml_tweedle_dum_to_affine"

external of_affine : Affine.t -> t = "caml_tweedle_dum_of_affine"

external of_affine_coordinates :
  Marlin_plonk_bindings_tweedle_fp.t -> Marlin_plonk_bindings_tweedle_fp.t -> t
  = "caml_tweedle_dum_of_affine_coordinates"

external endo_base : unit -> Marlin_plonk_bindings_tweedle_fp.t = "caml_tweedle_dum_endo_base"

external endo_scalar : unit -> Marlin_plonk_bindings_tweedle_fq.t = "caml_tweedle_dum_endo_scalar"
