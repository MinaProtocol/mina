type t

external create : unit -> t = "caml_pasta_fq_poseidon_params_create"

external block_cipher : t -> Kimchi_bindings.FieldVectors.Fq.t -> unit
  = "caml_pasta_fq_poseidon_block_cipher"
