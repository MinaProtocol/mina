type t

module Affine = struct
  type t =
    (Marlin_plonk_bindings_pasta_fp.t * Marlin_plonk_bindings_pasta_fp.t)
    Marlin_plonk_bindings_types.Or_infinity.t
end

external one : unit -> t = "caml_pasta_pallas_one"

external add : t -> t -> t = "caml_pasta_pallas_add"

external sub : t -> t -> t = "caml_pasta_pallas_sub"

external negate : t -> t = "caml_pasta_pallas_negate"

external double : t -> t = "caml_pasta_pallas_double"

external scale :
  t -> Marlin_plonk_bindings_pasta_fq.t -> t
  = "caml_pasta_pallas_scale"

external random : unit -> t = "caml_pasta_pallas_random"

external rng : int -> t = "caml_pasta_pallas_rng"

external to_affine : t -> Affine.t = "caml_pasta_pallas_to_affine"

external of_affine : Affine.t -> t = "caml_pasta_pallas_of_affine"

external of_affine_coordinates :
  Marlin_plonk_bindings_pasta_fp.t -> Marlin_plonk_bindings_pasta_fp.t -> t
  = "caml_pasta_pallas_of_affine_coordinates"

external endo_base :
  unit -> Marlin_plonk_bindings_pasta_fp.t
  = "caml_pasta_pallas_endo_base"

external endo_scalar :
  unit -> Marlin_plonk_bindings_pasta_fq.t
  = "caml_pasta_pallas_endo_scalar"

external affine_deep_copy :
  Affine.t -> Affine.t
  = "caml_pasta_pallas_affine_deep_copy"

let%test "affine dump_copy" =
  let x = random () |> to_affine in
  affine_deep_copy x = x
