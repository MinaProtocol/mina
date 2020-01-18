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
  R1cs_constraint_system.Make (Fq) (Snarky_bn382.Fq.Constraint_matrix)
module Var = Var
open Core_kernel

module Verification_key = struct
  open Snarky_bn382

  type t = Fq_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Oracles = struct
end

module Proving_key = struct
  type t = Snarky_bn382.Fq_index.t

  include Binable.Of_binable
            (Unit)
            (struct
              type t = unit

              let to_binable _ = ()

              let of_binable () = ()
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
    lazy
      (let start = Time.now () in
       let res = Snarky_bn382.Fq_urs.read "/home/izzy/pickles/urs" in
       let stop = Time.now () in
       Core.printf
         !"read urs in %{sexp:Time.Span.t}\n%!"
         (Time.diff stop start) ;
       res)

  let create
      { R1CS_constraint_system.public_input_size
      ; auxiliary_input_size
      ; m= {a; b; c}
      ; weight= _ } =
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

module Proof = struct
  include Unit

  type message = unit

  let create ?message:_ _pk ~primary:_ ~auxiliary:_ = ()

  let verify ?message:_ _ _ _ = true
end
