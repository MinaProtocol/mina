type t

module Affine = struct
  type t =
    (Marlin_plonk_bindings_tweedle_fq.t * Marlin_plonk_bindings_tweedle_fq.t)
    Marlin_plonk_bindings_types.Or_infinite.t
end

external one : unit -> t = "caml_tweedle_dee_one"

external add : t -> t -> t = "caml_tweedle_dee_add"

external sub : t -> t -> t = "caml_tweedle_dee_sub"

external negate : t -> t = "caml_tweedle_dee_negate"

external double : t -> t = "caml_tweedle_dee_double"

external scale :
  t -> Marlin_plonk_bindings_tweedle_fp.t -> t
  = "caml_tweedle_dee_scale"

external random : unit -> t = "caml_tweedle_dee_random"

external rng : int -> t = "caml_tweedle_dee_rng"

external to_affine : t -> Affine.t = "caml_tweedle_dee_to_affine"

external of_affine : Affine.t -> t = "caml_tweedle_dee_of_affine"

external of_affine_coordinates :
  Marlin_plonk_bindings_tweedle_fq.t -> Marlin_plonk_bindings_tweedle_fq.t -> t
  = "caml_tweedle_dee_of_affine_coordinates"
