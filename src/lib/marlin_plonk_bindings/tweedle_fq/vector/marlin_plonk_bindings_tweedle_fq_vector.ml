type t

external create : unit -> t = "caml_tweedle_fq_vector_create"

external length : t -> int = "caml_tweedle_fq_vector_length"

external emplace_back :
  t -> Marlin_plonk_bindings_tweedle_fq.t -> unit
  = "caml_tweedle_fq_vector_emplace_back"

external get :
  t -> int -> Marlin_plonk_bindings_tweedle_fq.t option
  = "caml_tweedle_fq_vector_get"
