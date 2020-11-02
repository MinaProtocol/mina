open Marlin_plonk_bindings_types

type t =
  { domain: Marlin_plonk_bindings_tweedle_fq.t Plonk_domain.t
  ; max_poly_size: int
  ; max_quot_size: int
  ; urs: Marlin_plonk_bindings_tweedle_fq_urs.t
  ; evals:
      Marlin_plonk_bindings_tweedle_fq_urs.Poly_comm.t
      Plonk_verification_evals.t
  ; shifts: Marlin_plonk_bindings_tweedle_fq.t Plonk_verification_shifts.t }

module Raw = struct
  type t

  external create :
    Marlin_plonk_bindings_tweedle_fq_index.t -> t
    = "caml_tweedle_fq_plonk_verifier_index_raw_create"

  external read :
    Marlin_plonk_bindings_tweedle_fq_urs.t -> string -> t
    = "caml_tweedle_fq_plonk_verifier_index_raw_read"

  external write :
    t -> string -> unit
    = "caml_tweedle_fq_plonk_verifier_index_raw_write"

  external of_parts :
       max_poly_size:int
    -> max_quot_size:int
    -> Marlin_plonk_bindings_tweedle_fq_urs.t
    -> Marlin_plonk_bindings_tweedle_fq_urs.Poly_comm.t
       Plonk_verification_evals.t
    -> Marlin_plonk_bindings_tweedle_fq.t Plonk_verification_shifts.t
    = "caml_tweedle_fq_plonk_verifier_index_raw_of_parts"
end

external create :
  Marlin_plonk_bindings_tweedle_fq_index.t -> t
  = "caml_tweedle_fq_plonk_verifier_index_create"

external read :
  Marlin_plonk_bindings_tweedle_fq_urs.t -> string -> t
  = "caml_tweedle_fq_plonk_verifier_index_read"

external write :
  t -> string -> unit
  = "caml_tweedle_fq_plonk_verifier_index_write"

external to_raw :
  t -> Raw.t
  = "caml_tweedle_fq_plonk_verifier_index_raw_of_ocaml"

external of_raw_copy :
  Raw.t -> t
  = "caml_tweedle_fq_plonk_verifier_index_ocaml_of_raw"
