module Bigint = struct
  module R = struct
    include Bigint.R

    let to_field x =
      let r = Snarky_bn382.Fp.of_bigint x in
      Gc.finalise Snarky_bn382.Fp.delete r ;
      r

    let of_field x =
      let r = Snarky_bn382.Fp.to_bigint x in
      Gc.finalise Snarky_bn382.Bigint.delete r ;
      r
  end
end

open Core_kernel

let field_size : Bigint.R.t = Snarky_bn382.Fp.size ()

module Field = Fp
module Proving_key = Proving_key
module R1CS_constraint_system =
  R1cs_constraint_system.Make (Fp) (Snarky_bn382.Fp.Constraint_matrix)
module Var = Var

module Verification_key = struct
  open Snarky_bn382

  type t = Fp_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Oracles = struct
  open Snarky_bn382

  let create vk input (pi : Proof.t) =
    let t = Fp_oracles.create vk (Proof.to_backend input pi) in
    Caml.Gc.finalise Fp_oracles.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Field.delete x ;
    x

  open Fp_oracles

  let alpha = field alpha

  let eta_a = field eta_a

  let eta_b = field eta_b

  let eta_c = field eta_c

  let beta1 = field beta1

  let beta2 = field beta2

  let beta3 = field beta3

  let batch = field batch

  let r_k = field r_k

  let r = field r

  let x_hat_beta1 = field x_hat_beta1

  let digest_before_evaluations = field digest_before_evaluations
end

module Keypair = struct
  module Fp_index = Snarky_bn382.Fp_index
  module Fp_verifier_index = Snarky_bn382.Fp_verifier_index

  type t = Fp_index.t

  let urs =
    let path = "/home/izzy/pickles/urs" in
    (*
      let res = Snarky_bn382.Fp_urs.create (Unsigned.Size_t.of_int (2 * 786_433)) in
    Snarky_bn382.Fp_urs.write res path;
    failwith "hi''"; *)
    lazy
      (let start = Time.now () in
       let res = Snarky_bn382.Fp_urs.read path in
       let stop = Time.now () in
       Core.printf
         !"read urs in %{sexp:Time.Span.t}\n%!"
         (Time.diff stop start) ;
       res)

  let create
      { R1CS_constraint_system.public_input_size
      ; auxiliary_input_size
      ; m= {a; b; c}
      ; weight } =
    Core.printf
      !"pairing weight is %{sexp:R1cs_constraint_system.Weight.t}\n%!"
      weight ;
    let vars = 1 + public_input_size + auxiliary_input_size in
    Fp_index.create a b c
      (Unsigned.Size_t.of_int vars)
      (Unsigned.Size_t.of_int (public_input_size + 1))
      (Lazy.force urs)

  let vk t = Fp_verifier_index.create t

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
        ; c= Fp_index.c_val_comm t }
    ; rc=
        { a= Fp_index.a_rc_comm t
        ; b= Fp_index.b_rc_comm t
        ; c= Fp_index.c_rc_comm t } }
    |> Matrix_evals.map ~f:(Abc.map ~f:G1.Affine.of_backend)
end

module Proof = Proof
