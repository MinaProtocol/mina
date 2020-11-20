open Marlin_plonk_bindings_types

type t = Marlin_plonk_bindings_pasta_fq.t Oracles.t

external create_raw :
     Marlin_plonk_bindings_pasta_fq_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_pasta_fq_verifier_index.Raw.t
  -> Marlin_plonk_bindings_pasta_fq_proof.t
  -> t
  = "caml_pasta_fq_plonk_oracles_create_raw"

external create :
     Marlin_plonk_bindings_pasta_fq_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_pasta_fq_verifier_index.t
  -> Marlin_plonk_bindings_pasta_fq_proof.t
  -> t
  = "caml_pasta_fq_plonk_oracles_create"
