open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let test () =
  let tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:2 ~override_wrap_domain:N1 ~name:"chunked_circuits"
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                (* Remember that each of these counts for *half* a row, so we
                   need 2^17 of them to fill 2^16 rows.
                *)
                for _ = 0 to 1 lsl 17 do
                  ignore (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
                done ;
                (* We must now appease the permutation argument gods, to ensure
                   that the 7th permuted column has polynomial degree larger
                   than 2^16, and thus that its high chunks are non-zero.
                   Suckiness of linearization strikes again!
                *)
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
  let module Requests = struct
    type _ Snarky_backendless.Request.t +=
      | Proof : Nat.N0.n Pickles.Proof.t Snarky_backendless.Request.t

    let handler (proof : _ Pickles.Proof.t)
        (Snarky_backendless.Request.With { request; respond }) =
      match request with
      | Proof ->
          respond (Provide proof)
      | _ ->
          respond Unhandled
  end in
  (* force vk creation  *)
  let _vk =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Pickles.Side_loaded.Verification_key.of_compiled tag )
  in
  let tag2, _cache_handle, recursive_proof, Pickles.Provers.[ recursive_prove ]
      =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N1)
      ~name:"recursion over chunks"
      ~choices:(fun ~self:_ ->
        [ { identifier = "recurse over 2^17"
          ; prevs = [ tag ]
          ; main =
              (fun _ ->
                let proof =
                  exists (Typ.prover_value ()) ~request:(fun () ->
                      Requests.Proof )
                in
                { previous_proof_statements =
                    [ { public_input = ()
                      ; proof
                      ; proof_must_verify = Boolean.true_
                      }
                    ]
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
      ()
  in
  (* force vk creation  *)
  let _vk =
    Async.Thread_safe.block_on_async_exn (fun () ->
        Pickles.Side_loaded.Verification_key.of_compiled tag2 )
  in
  let module Proof = (val proof) in
  let module Recursive_proof = (val recursive_proof) in
  let test_prove () =
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) ) ;
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () ->
          recursive_prove ~handler:(Requests.handler proof) () )
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Recursive_proof.verify [ (public_input, proof) ] ) )
  in
  test_prove ()

let () =
  test () ;
  Alcotest.run "Chunked circuit"
    [ ("2^16", [ ("prove and verify", `Quick, test) ]) ]
