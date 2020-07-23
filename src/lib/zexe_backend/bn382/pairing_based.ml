open Basic

module Bigint = struct
  module R = struct
    include Fp.Bigint

    let to_field = Fp.of_bigint

    let of_field = Fp.to_bigint
  end
end

open Core_kernel

let field_size : Bigint.R.t = Snarky_bn382.Fp.size ()

module Field = Fp

module Proving_key = struct
  open Core
  open Snarky_bn382

  type t = Fp_index.t

  include Binable.Of_binable
            (Unit)
            (struct
              type t = Fp_index.t

              let to_binable _ = ()

              let of_binable () = failwith "TODO"
            end)

  let is_initialized _ = `Yes

  let set_constraint_system _ _ = ()

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Verification_key = struct
  open Snarky_bn382

  type t = Fp_verifier_index.t

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Mat = struct
  include Snarky_bn382.Fp.Constraint_matrix

  let create () =
    let t = create () in
    Caml.Gc.finalise delete t ; t
end

module R1CS_constraint_system =
  Zexe_backend_common.R1cs_constraint_system.Make (Fp) (Mat)
module Var = Zexe_backend_common.Var

module Oracles = struct
  open Snarky_bn382

  let create vk input (pi : Pairing_based_proof.t) =
    let t = Fp_oracles.create vk (Pairing_based_proof.to_backend input pi) in
    Caml.Gc.finalise Fp_oracles.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Field.delete x ;
    x

  let scalar_challenge f t = Pickles_types.Scalar_challenge.create (field f t)

  open Fp_oracles

  let alpha = field alpha

  let eta_a = field eta_a

  let eta_b = field eta_b

  let eta_c = field eta_c

  let beta1 = scalar_challenge beta1

  let beta2 = scalar_challenge beta2

  let beta3 = scalar_challenge beta3

  let batch = scalar_challenge batch

  let r_k = scalar_challenge r_k

  let r = scalar_challenge r

  let x_hat_beta1 = field x_hat_beta1

  let digest_before_evaluations = field digest_before_evaluations
end

module Keypair = struct
  module Fp_index = Snarky_bn382.Fp_index
  module Fp_verifier_index = Snarky_bn382.Fp_verifier_index

  type t = Fp_index.t

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let set_urs_info ?(degree = 2 * 786_433) specs =
      Set_once.set_exn urs_info Lexing.dummy_pos (degree, specs)
    in
    let load () =
      match !urs with
      | Some urs ->
          urs
      | None ->
          let degree, specs =
            match Set_once.get urs_info with
            | None ->
                failwith "Pairing_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Sync.Disk_storable.simple
              (fun () -> "fp-urs")
              (fun () ~path -> Snarky_bn382.Fp_urs.read path)
              Snarky_bn382.Fp_urs.write
          in
          let u =
            match Key_cache.Sync.read specs store () with
            | Ok (u, _) ->
                u
            | Error _e ->
                let urs =
                  Snarky_bn382.Fp_urs.create (Unsigned.Size_t.of_int degree)
                in
                let _ =
                  Key_cache.Sync.write
                    (List.filter specs ~f:(function
                      | On_disk _ ->
                          true
                      | S3 _ ->
                          false ))
                    store () urs
                in
                urs
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let create
      { Zexe_backend_common.R1cs_constraint_system.public_input_size
      ; auxiliary_input_size
      ; m= {a; b; c}
      ; weight } =
    let vars = 1 + public_input_size + auxiliary_input_size in
    Fp_index.create a b c
      (Unsigned.Size_t.of_int vars)
      (Unsigned.Size_t.of_int (public_input_size + 1))
      (load_urs ())

  let vk t = Fp_verifier_index.create t

  let pk = Fn.id

  open Pickles_types

  let vk_commitments t : G1.Affine.t Abc.t Matrix_evals.t =
    let open Fp_verifier_index in
    { row= {Abc.a= a_row_comm t; b= b_row_comm t; c= c_row_comm t}
    ; col= {a= a_col_comm t; b= b_col_comm t; c= c_col_comm t}
    ; value= {a= a_val_comm t; b= b_val_comm t; c= c_val_comm t}
    ; rc= {a= a_rc_comm t; b= b_rc_comm t; c= c_rc_comm t} }
    |> Matrix_evals.map ~f:(Abc.map ~f:G1.Affine.of_backend)
end

module Proof = Pairing_based_proof
