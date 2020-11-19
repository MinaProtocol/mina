open Marlin_plonk_bindings_types

type t =
  ( Marlin_plonk_bindings_tweedle_fp.t
  , Marlin_plonk_bindings_tweedle_fp_urs.t
  , Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t )
  Plonk_verifier_index.t

module Raw = struct
  type t

  external create :
    Marlin_plonk_bindings_tweedle_fp_index.t -> t
    = "caml_tweedle_fp_plonk_verifier_index_raw_create"

  external read :
    ?offset:int -> Marlin_plonk_bindings_tweedle_fp_urs.t -> string -> t
    = "caml_tweedle_fp_plonk_verifier_index_raw_read"

  external write :
    t -> string -> unit
    = "caml_tweedle_fp_plonk_verifier_index_raw_write"

  external of_parts :
       max_poly_size:int
    -> max_quot_size:int
    -> log_size_of_group:int
    -> Marlin_plonk_bindings_tweedle_fp_urs.t
    -> Marlin_plonk_bindings_tweedle_fp_urs.Poly_comm.t
       Plonk_verification_evals.t
    -> Marlin_plonk_bindings_tweedle_fp.t Plonk_verification_shifts.t
    = "caml_tweedle_fp_plonk_verifier_index_raw_of_parts"
end

external create :
  Marlin_plonk_bindings_tweedle_fp_index.t -> t
  = "caml_tweedle_fp_plonk_verifier_index_create"

external read :
  ?offset:int -> Marlin_plonk_bindings_tweedle_fp_urs.t -> string -> t
  = "caml_tweedle_fp_plonk_verifier_index_read"

external write :
  t -> string -> unit
  = "caml_tweedle_fp_plonk_verifier_index_write"

external to_raw :
  t -> Raw.t
  = "caml_tweedle_fp_plonk_verifier_index_raw_of_ocaml"

external of_raw_copy :
  Raw.t -> t
  = "caml_tweedle_fp_plonk_verifier_index_ocaml_of_raw"

external shifts :
     log2_size:int
  -> Marlin_plonk_bindings_tweedle_fp.t Plonk_verification_shifts.t
  = "caml_tweedle_fp_plonk_verifier_index_shifts"
