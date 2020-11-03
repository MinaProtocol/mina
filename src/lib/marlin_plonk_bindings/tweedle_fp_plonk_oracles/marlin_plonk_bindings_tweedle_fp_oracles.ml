open Marlin_plonk_bindings_types

external create_raw :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.Raw.t
  -> Marlin_plonk_bindings_tweedle_fp_proof.t
  -> Marlin_plonk_bindings_tweedle_fp.t Oracles.t
  = "caml_tweedle_fp_plonk_oracles_create_raw"

external create :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.t
  -> Marlin_plonk_bindings_tweedle_fp_proof.t
  -> Marlin_plonk_bindings_tweedle_fp.t Oracles.t
  = "caml_tweedle_fp_plonk_oracles_create"
