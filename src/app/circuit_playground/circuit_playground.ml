open Core


(* there is also Tock, these two elliptic curves form a cycle *)
module Tick = Kimchi_backend.Pasta.Vesta_based_plonk

(* Vesta and Pallas are the largest asteroids that aren't Ceres *)
(* this doesn't help with ZK, but i think it's good to know *)

(* there is also a plain monadic API, Snark.Make (Tick) *)
module Impl = Snarky_backendless.Snark.Run.Make (Tick)
open Impl

module FibonacciData = struct
  module Request = struct
    type _ Snarky_backendless.Request.t +=
      | Hidden_total : Field.Constant.t Snarky_backendless.Request.t

    let handler (hidden_total : Field.Constant.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Hidden_total ->
          respond (Provide hidden_total)
      | _ ->
          respond Unhandled
  end

  let input_typ = Typ.(tuple2 (list ~length:3 field) field)

  let return_typ = Typ.unit

  let list_product_gt ((l, lower_bound) : Field.t list * Field.t) () =
    let checked_product = List.fold ~init:Field.one l ~f:Field.( * ) in
    let hidden_total =
      exists Field.typ ~request:(fun () -> Request.Hidden_total)
    in
    Field.Assert.equal checked_product hidden_total ;
    Field.Assert.gte ~bit_length:3 checked_product lower_bound
end

open FibonacciData

let my_list = List.map ~f:Field.Constant.of_int [ 1; 2; 3 ]

let private_total = 6

(* this is a really bad lower bound for
   an element of the fibonacci sequence,
   but it doesn't hurt to never lose. *)
let lower_bound_guess = Field.Constant.of_int 1

let circuit public_input (private_input : int) () =
  handle
    (list_product_gt public_input)
    (FibonacciData.Request.handler (Field.Constant.of_int private_input))

(* NB: it says "R1CS" but it is _not_ reduced to such a form
   (it is in fact just a list of kimchi gates) *)

let constraints =
  constraint_system ~input_typ ~return_typ (fun inp -> circuit inp 6)

let () = printf "%s\n" (R1CS_constraint_system.to_asm constraints)

let () =
  printf "%d constraints and %d rows, generating keypair...\n"
    (R1CS_constraint_system.num_constraints constraints)
    (R1CS_constraint_system.get_rows_len constraints)

let proof_keypair = Tick.Keypair.create ~prev_challenges:0 constraints

let () =
  Kimchi_bindings.Protocol.Index.Fp.write_html proof_keypair.index
    (Some "circuit.html")

let prover_index = Tick.Keypair.pk proof_keypair

let proving_start = Time.now ()

let proof, (() as _public_output) =
  generate_witness_conv
    ~f:(fun { Impl.Proof_inputs.auxiliary_inputs; public_inputs }
            next_statement_hashed ->
      let proof =
        (* Only block_on_async for testing; do not do this in production!! *)
        Promise.block_on_async_exn (fun () ->
            Tick.Proof.create_async ~primary:public_inputs
              ~auxiliary:auxiliary_inputs ~message:[] prover_index )
      in
      (proof, next_statement_hashed) )
    ~input_typ ~return_typ
    (fun inp -> circuit inp 6)
    (my_list, lower_bound_guess)

let proving_time = Time.abs_diff (Time.now ()) proving_start

let () = printf "Proving time: %f ms\n" (Time.Span.to_ms proving_time)

let verifier_index = Tick.Keypair.vk proof_keypair

(* encoding the public input like this is low level and annoying, there's gotta be some other way? *)
let public_input =
  let fv = Kimchi_bindings.FieldVectors.Fp.create () in
  List.iter my_list ~f:(Kimchi_bindings.FieldVectors.Fp.emplace_back fv) ;
  Kimchi_bindings.FieldVectors.Fp.emplace_back fv
    (Field.Constant.of_int private_total) ;
  fv

let verifying_start = Time.now ()

let is_valid = Tick.Proof.verify proof verifier_index public_input

let verifying_time = Time.abs_diff (Time.now ()) verifying_start

let () =
  printf "Statement is %s (verified in %f ms)\n"
    (if is_valid then "TRUE!" else "FALSE!")
    (Time.Span.to_ms verifying_time)
