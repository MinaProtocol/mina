open Marlin_plonk_bindings_types

type t =
  ( Marlin_plonk_bindings_tweedle_fp.t
  , Marlin_plonk_bindings_tweedle_dee.Affine.t
  , Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t )
  Plonk_proof.t

(* TODO-someday: [prev_challenges] should be an array of arrays, not a flat array. *)
external create :
     Marlin_plonk_bindings_tweedle_fp_index.t
  -> primary_input:Marlin_plonk_bindings_tweedle_fp_vector.t
  -> auxiliary_input:
  (
    Marlin_plonk_bindings_tweedle_fp.t array *
    Marlin_plonk_bindings_tweedle_fp.t array *
    Marlin_plonk_bindings_tweedle_fp.t array *
    Marlin_plonk_bindings_tweedle_fp.t array *
    Marlin_plonk_bindings_tweedle_fp.t array
  )
  -> prev_challenges:Marlin_plonk_bindings_tweedle_fp.t array
  -> prev_sgs:Marlin_plonk_bindings_tweedle_dee.Affine.t array
  -> t
  = "caml_tweedle_fp_plonk_proof_create"

external verify_raw :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.Raw.t
  -> t
  -> bool
  = "caml_tweedle_fp_plonk_proof_verify_raw"

external verify :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.t
  -> t
  -> bool
  = "caml_tweedle_fp_plonk_proof_verify"

external batch_verify_raw :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.Raw.t array
  -> t array
  -> bool
  = "caml_tweedle_fp_plonk_proof_batch_verify_raw"

external batch_verify :
     Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t array array
  -> Marlin_plonk_bindings_tweedle_fp_verifier_index.t array
  -> t array
  -> bool
  = "caml_tweedle_fp_plonk_proof_batch_verify"
