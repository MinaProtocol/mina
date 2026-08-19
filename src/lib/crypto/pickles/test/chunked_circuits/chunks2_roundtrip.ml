open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

(* Regression test for the chunked-proof round-trip bug (issue #18872).

   A num_chunks > 1 proof should round-trip through Pickles.Proof.to_base64 /
   of_base64 and still verify. Today, to_repr collapses each side of
   prev_evals.evals.public_input to chunk 0 only (because the Stable.V1
   serialized type has public_input : 'f * 'f rather than 'f array * 'f array),
   so for nc = 2 the deserialized proof no longer verifies. *)
let test () =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:2 ~override_wrap_domain:N1 ~name:"chunked_circuits_roundtrip"
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                for _ = 0 to 1 lsl 17 do
                  ignore (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
                done ;
                let fresh_zero = fresh_zero () in
                Impl.assert_
                  (Raw
                     { kind = Generic
                     ; values =
                         [| fresh_zero
                          ; fresh_zero
                          ; fresh_zero
                          ; fresh_zero
                          ; fresh_zero
                          ; fresh_zero
                          ; fresh_zero
                         |]
                     ; coeffs = [||]
                     } ) ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
      ()
  in
  let module Proof = (val proof) in
  let module P_io = Pickles.Proof.Make (Nat.N0) in
  let public_input, (), proof =
    Async.Thread_safe.block_on_async_exn (fun () -> prove ())
  in
  (* Sanity check: the freshly generated proof verifies. *)
  Or_error.ok_exn
    (Async.Thread_safe.block_on_async_exn (fun () ->
         Proof.verify [ (public_input, proof) ] ) ) ;
  let proof' =
    match P_io.of_base64 (P_io.to_base64 proof) with
    | Ok p ->
        p
    | Error e ->
        failwith ("Proof.of_base64 failed: " ^ e)
  in
  (* The deserialized proof should still verify. Today, this raises because
     chunks 1..n-1 of public_input were dropped on serialization. *)
  Or_error.ok_exn
    (Async.Thread_safe.block_on_async_exn (fun () ->
         Proof.verify [ (public_input, proof') ] ) )

let () =
  Alcotest.run "Chunked proof base64 round-trip"
    [ ("2^16", [ ("verify after to_base64/of_base64", `Quick, test) ]) ]
