type t =
  ( Marlin_plonk_bindings_pasta_fp.t
  , Marlin_plonk_bindings_pasta_vesta.Affine.t
  , Marlin_plonk_bindings_pasta_fp_urs.Poly_comm.t )
  Marlin_plonk_bindings_types.Plonk_proof.t

external create :
     Marlin_plonk_bindings_pasta_fp_index.t
  -> primary_input:Marlin_plonk_bindings_pasta_fp_vector.t
  -> auxiliary_input:Marlin_plonk_bindings_pasta_fp_vector.t
  -> prev_challenges:Marlin_plonk_bindings_pasta_fp.t array
  -> prev_sgs:Marlin_plonk_bindings_pasta_vesta.Affine.t array
  -> t = "caml_pasta_fp_plonk_proof_create"

external verify :
     Marlin_plonk_bindings_pasta_fp_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_pasta_fp_verifier_index.t
  -> t
  -> bool = "caml_pasta_fp_plonk_proof_verify"

external batch_verify :
     Marlin_plonk_bindings_pasta_fp_urs.Poly_comm.t array array
  -> Marlin_plonk_bindings_pasta_fp_verifier_index.t array
  -> t array
  -> bool = "caml_pasta_fp_plonk_proof_batch_verify"

external dummy : unit -> t = "caml_pasta_fp_plonk_proof_dummy"

external deep_copy : t -> t = "caml_pasta_fp_plonk_proof_deep_copy"
