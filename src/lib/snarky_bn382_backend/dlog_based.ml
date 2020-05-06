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
    let pi = Proof.to_backend prev_challenge input pi in
    let t = Fq_oracles.create vk pi in
    Caml.Gc.finalise Fq_oracles.delete t ;
    t

  let field f t =
    let x = f t in
    Caml.Gc.finalise Fq.delete x ;
    x

  let scalar_challenge f t = Pickles_types.Scalar_challenge.create (field f t)

  open Fq_oracles

  let alpha = field alpha

  let eta_a = field eta_a

  let eta_b = field eta_b

  let eta_c = field eta_c

  let beta1 = scalar_challenge beta1

  let beta2 = scalar_challenge beta2

  let beta3 = scalar_challenge beta3

  let polys = scalar_challenge polys

  let evals = scalar_challenge evals

  (* TODO: Leaky *)
  let opening_prechallenges t =
    let open Snarky_bn382 in
    let t = opening_prechallenges t in
    Array.init (Fq.Vector.length t) ~f:(fun i ->
        Pickles_types.Scalar_challenge.create (Fq.Vector.get t i) )

  let x_hat t =
    let t = x_hat_nocopy t in
    let fq f = field f t in
    Snarky_bn382.Fq_triple.(fq f0, fq f1, fq f2)

  let digest_before_evaluations = field digest_before_evaluations
end

module Proving_key = struct
  type t = Snarky_bn382.Fq_index.t

  include Binable.Of_binable
            (Unit)
            (struct
              type nonrec t = t

              let to_binable _ = ()

              let of_binable () = failwith "TODO"
            end)

  let is_initialized _ = `Yes

  let set_constraint_system _ _ = ()

  let to_string _ = failwith "TODO"

  let of_string _ = failwith "TODO"
end

module Keypair = struct
  module Fq_index = Snarky_bn382.Fq_index
  module Fq_verifier_index = Snarky_bn382.Fq_verifier_index

  type t = Fq_index.t

  let set_urs_info, load_urs =
    let urs_info = Set_once.create () in
    let urs = ref None in
    let set_urs_info ?(degree = 1 lsl 20) specs =
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
                failwith "Dlog_based.urs: Info not set"
            | Some t ->
                t
          in
          let store =
            Key_cache.Disk_storable.simple
              (fun () -> "fq-urs")
              (fun () ~path -> Snarky_bn382.Fq_urs.read path)
              Snarky_bn382.Fq_urs.write
          in
          let u =
            Async.Thread_safe.block_on_async_exn (fun () ->
                let open Async in
                match%bind Key_cache.read specs store () with
                | Ok (u, _) ->
                    return u
                | Error _e ->
                    let urs =
                      Snarky_bn382.Fq_urs.create
                        (Unsigned.Size_t.of_int degree)
                    in
                    let%map _ =
                      Key_cache.write
                        (List.filter specs ~f:(function
                          | On_disk _ ->
                              true
                          | S3 _ ->
                              false ))
                        store () urs
                    in
                    urs )
          in
          urs := Some u ;
          u
    in
    (set_urs_info, load)

  let () =
    set_urs_info
      [On_disk {directory= "/home/izzy/pickles-new/"; should_write= true}]

  let create
      { R1cs_constraint_system.public_input_size
      ; auxiliary_input_size
      ; m= {a; b; c}
      ; weight } =
    let vars = 1 + public_input_size + auxiliary_input_size in
    Core.printf "dlog weight %d\n%!"
      (R1cs_constraint_system.Weight.norm weight) ;
    Fq_index.create a b c
      (Unsigned.Size_t.of_int vars)
      (Unsigned.Size_t.of_int (public_input_size + 1))
      (load_urs ())

  let vk t = Fq_verifier_index.create t

  let pk = Fn.id

  open Pickles_types

  let vk_commitments t : G.Affine.t Abc.t Matrix_evals.t =
    let open Fq_verifier_index in
    { row= {Abc.a= a_row_comm t; b= b_row_comm t; c= c_row_comm t}
    ; col= {a= a_col_comm t; b= b_col_comm t; c= c_col_comm t}
    ; value= {a= a_val_comm t; b= b_val_comm t; c= c_val_comm t}
    ; rc= {a= a_rc_comm t; b= b_rc_comm t; c= c_rc_comm t} }
    |> Matrix_evals.map ~f:(Abc.map ~f:G.Affine.of_backend)
end
