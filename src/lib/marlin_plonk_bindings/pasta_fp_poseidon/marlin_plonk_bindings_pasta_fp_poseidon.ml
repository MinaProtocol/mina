type t

external create : unit -> t = "caml_pasta_fp_poseidon_params_create"

external block_cipher : t -> Marlin_plonk_bindings_pasta_fp_vector.t -> unit
  = "caml_pasta_fp_poseidon_block_cipher"
