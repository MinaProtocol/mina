open Core_kernel
module Fp_index = Snarky_bn382.Fp_index

type t = Fp_index.t

let create
    { R1cs_constraint_system.public_input_size
    ; auxiliary_input_size
    ; m= {a; b; c}
    ; weight= _ } =
  let vars = 1 + public_input_size + auxiliary_input_size in
  Fp_index.create a b c
    (Unsigned.Size_t.of_int vars)
    (Unsigned.Size_t.of_int (public_input_size + 1))

let vk _ = ""

let pk = Fn.id

open Pickles_types

let vk_commitments t : G1.Affine.t Abc.t Matrix_evals.t =
  { row=
      { Abc.a= Fp_index.a_row_comm t
      ; b= Fp_index.b_row_comm t
      ; c= Fp_index.c_row_comm t }
  ; col=
      { a= Fp_index.a_col_comm t
      ; b= Fp_index.b_col_comm t
      ; c= Fp_index.c_col_comm t }
  ; value=
      { a= Fp_index.a_val_comm t
      ; b= Fp_index.b_val_comm t
      ; c= Fp_index.c_val_comm t } }
  |> Matrix_evals.map ~f:(Abc.map ~f:G1.Affine.of_backend)
