type t

external create : unit -> t = "caml_pasta_fp_poseidon_params_create"

external block_cipher : t -> Kimchi_bindings.FieldVectors.Fp.t -> unit
  = "caml_pasta_fp_poseidon_block_cipher"
