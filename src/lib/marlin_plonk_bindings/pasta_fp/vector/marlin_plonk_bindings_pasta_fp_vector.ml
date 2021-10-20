type t

type elt = Marlin_plonk_bindings_pasta_fp.t

external create : unit -> t = "caml_pasta_fp_vector_create"

external length : t -> int = "caml_pasta_fp_vector_length"

external emplace_back : t -> elt -> unit = "caml_pasta_fp_vector_emplace_back"

external get : t -> int -> elt = "caml_pasta_fp_vector_get"

external set : t -> int -> elt -> unit = "caml_pasta_fp_vector_set"
