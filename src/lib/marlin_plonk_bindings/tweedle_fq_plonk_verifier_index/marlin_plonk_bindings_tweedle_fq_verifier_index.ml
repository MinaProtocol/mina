open Marlin_plonk_bindings_types

type t =
  ( Marlin_plonk_bindings_tweedle_fq.t
  , Marlin_plonk_bindings_tweedle_fq_urs.t
  , Marlin_plonk_bindings_tweedle_fq_urs.Poly_comm.t )
  Plonk_verifier_index.t

external create :
  Marlin_plonk_bindings_tweedle_fq_index.t -> t
  = "caml_tweedle_fq_plonk_verifier_index_create"

external read :
  ?offset:int -> Marlin_plonk_bindings_tweedle_fq_urs.t -> string -> t
  = "caml_tweedle_fq_plonk_verifier_index_read"

external write :
  ?append:bool -> t -> string -> unit
  = "caml_tweedle_fq_plonk_verifier_index_write"

external shifts :
     log2_size:int
  -> Marlin_plonk_bindings_tweedle_fq.t Plonk_verification_shifts.t
  = "caml_tweedle_fq_plonk_verifier_index_shifts"

external dummy : unit -> t = "caml_tweedle_fq_plonk_verifier_index_dummy"

external deep_copy : t -> t = "caml_tweedle_fq_plonk_verifier_index_deep_copy"

let%test "deep_copy" =
  let x = dummy () in
  deep_copy x = x
