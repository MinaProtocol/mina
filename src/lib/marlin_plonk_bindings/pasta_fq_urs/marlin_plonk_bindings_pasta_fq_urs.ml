type t

module Poly_comm = struct
  type t =
    Marlin_plonk_bindings_pasta_pallas.Affine.t
    Marlin_plonk_bindings_types.Poly_comm.t
end

external create : int -> t = "caml_pasta_fq_urs_create"

external write : ?append:bool -> t -> string -> unit = "caml_pasta_fq_urs_write"

external read : ?offset:int -> string -> t option = "caml_pasta_fq_urs_read"

external lagrange_commitment : t -> domain_size:int -> int -> Poly_comm.t
  = "caml_pasta_fq_urs_lagrange_commitment"

external commit_evaluations :
  t -> domain_size:int -> Marlin_plonk_bindings_pasta_fq.t array -> Poly_comm.t
  = "caml_pasta_fq_urs_commit_evaluations"

external b_poly_commitment :
  t -> Marlin_plonk_bindings_pasta_fq.t array -> Poly_comm.t
  = "caml_pasta_fq_urs_b_poly_commitment"

external batch_accumulator_check :
     t
  -> Marlin_plonk_bindings_pasta_pallas.Affine.t array
  -> Marlin_plonk_bindings_pasta_fq.t array
  -> bool = "caml_pasta_fq_urs_batch_accumulator_check"

external batch_accumulator_generate :
     t
  -> int
  -> Marlin_plonk_bindings_pasta_fq.t array
  -> Marlin_plonk_bindings_pasta_pallas.Affine.t
  = "caml_pasta_fq_urs_batch_accumulator_generate"

external h : t -> Marlin_plonk_bindings_pasta_pallas.Affine.t
  = "caml_pasta_fq_urs_h"
