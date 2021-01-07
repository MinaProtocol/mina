type t

type elt = Marlin_plonk_bindings_pasta_fq.t

external create : unit -> t = "caml_pasta_fq_vector_create"

external length : t -> int = "caml_pasta_fq_vector_length"

external emplace_back : t -> elt -> unit = "caml_pasta_fq_vector_emplace_back"

external get : t -> int -> elt = "caml_pasta_fq_vector_get"
