module Bigint = struct
  module R = struct
    include Bigint.R

    let to_field x =
      let r = Snarky_bn382.Fq.of_bigint x in
      Gc.finalise Snarky_bn382.Fq.delete r ;
      r

    let of_field x =
      let r = Snarky_bn382.Fq.to_bigint x in
      Gc.finalise Snarky_bn382.Bigint.delete r ;
      r
  end
end

let field_size : Bigint.R.t = Snarky_bn382.Fp.size ()

module Field = Fq
module R1CS_constraint_system =
  R1cs_constraint_system.Make
    (Fq)
    (Snarky_bn382.Fq.Constraint_matrix)
module Var = Var
open Core_kernel

module Proof = Dlog_based_proof

module Verification_key = struct
  open Snarky_bn382

  type t = Fq_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Oracles = struct
  open Snarky_bn382

  let create vk prev_challenge input (pi : Proof.t) =
    printf "%s\n%!" __LOC__ ;
    let pi = Proof.to_backend prev_challenge input pi in
    printf "%s\n%!" __LOC__ ;
    let t = Fq_oracles.create vk pi in
    printf "%s\n%!" __LOC__ ;
    Caml.Gc.finalise Fq_oracles.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Fq.delete x ;
    x

  open Fq_oracles

  let alpha = field alpha

  let eta_a = field eta_a

  let eta_b = field eta_b

  let eta_c = field eta_c

  let beta1 = field beta1

  let beta2 = field beta2

  let beta3 = field beta3

  let polys = field polys

  let evals = field evals

  (* TODO: Leaky *)
  let opening_prechallenges t =
    let open Snarky_bn382 in
    let t = opening_prechallenges t in
    Array.init (Fq.Vector.length t) ~f:(Fq.Vector.get t)

  let x_hat t =
    let t = x_hat_nocopy t in
    let fq f = field f t in
    Snarky_bn382.Fq_triple.(
      fq f0, fq f1, fq f2)

  let digest_before_evaluations = field digest_before_evaluations
end

module Proving_key = struct
  type t = Snarky_bn382.Fq_index.t

  include Binable.Of_binable
            (Unit)
            (struct
              type nonrec t = t

              let to_binable _ = ()

              let of_binable () = failwith "todo"
            end)

  let is_initialized _ = `Yes

  let set_constraint_system _ _ = ()

  let to_string _ = ""

  let of_string _ = failwith "TODO"
end

module Keypair = struct
  module Fq_index = Snarky_bn382.Fq_index
  module Fq_verifier_index = Snarky_bn382.Fq_verifier_index

  type t = Fq_index.t

  let urs =
    let path = "/home/izzy/pickles/dlog-urs" in
    lazy
      (let start = Time.now () in
       let res = Snarky_bn382.Fq_urs.read path in
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
    Core.printf !"dlog weight is %{sexp:R1cs_constraint_system.Weight.t}\n%!" weight ;
    let vars = 1 + public_input_size + auxiliary_input_size in
    Fq_index.create a b c
      (Unsigned.Size_t.of_int vars)
      (Unsigned.Size_t.of_int (public_input_size + 1))
      (Lazy.force urs)

  let vk t = Fq_verifier_index.create t

  let pk = Fn.id

  open Pickles_types

  let vk_commitments t : G.Affine.t Abc.t Matrix_evals.t =
    { row=
        { Abc.a= Fq_index.a_row_comm t
        ; b= Fq_index.b_row_comm t
        ; c= Fq_index.c_row_comm t }
    ; col=
        { a= Fq_index.a_col_comm t
        ; b= Fq_index.b_col_comm t
        ; c= Fq_index.c_col_comm t }
    ; value=
        { a= Fq_index.a_val_comm t
        ; b= Fq_index.b_val_comm t
        ; c= Fq_index.c_val_comm t } 
    ; rc=
        { a= Fq_index.a_rc_comm t
        ; b= Fq_index.b_rc_comm t
        ; c= Fq_index.c_rc_comm t } 
    }
    |> Matrix_evals.map ~f:(Abc.map ~f:G.Affine.of_backend)
end
