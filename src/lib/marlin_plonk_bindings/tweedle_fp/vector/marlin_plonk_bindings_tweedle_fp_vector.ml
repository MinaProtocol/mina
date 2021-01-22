type t

type elt = Marlin_plonk_bindings_tweedle_fp.t

external create : unit -> t = "caml_tweedle_fp_vector_create"

external length : t -> int = "caml_tweedle_fp_vector_length"

external emplace_back :
  t -> elt -> unit
  = "caml_tweedle_fp_vector_emplace_back"

external get : t -> int -> elt = "caml_tweedle_fp_vector_get"
