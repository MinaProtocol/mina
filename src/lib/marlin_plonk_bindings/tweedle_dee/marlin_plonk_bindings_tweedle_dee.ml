type t

module Affine = struct
  type t =
    (Marlin_plonk_bindings_tweedle_fq.t * Marlin_plonk_bindings_tweedle_fq.t)
    Marlin_plonk_bindings_types.Or_infinity.t
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

external endo_base :
  unit -> Marlin_plonk_bindings_tweedle_fq.t
  = "caml_tweedle_dee_endo_base"

external endo_scalar :
  unit -> Marlin_plonk_bindings_tweedle_fp.t
  = "caml_tweedle_dee_endo_scalar"

external affine_deep_copy :
  Affine.t -> Affine.t
  = "caml_tweedle_dee_affine_deep_copy"

let%test "affine deep_copy" =
  let x = random () |> to_affine in
  affine_deep_copy x = x
