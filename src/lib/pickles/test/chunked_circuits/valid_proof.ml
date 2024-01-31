open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let constraint_constants =
  { Snark_keys_header.Constraint_constants.sub_windows_per_window = 0
  ; ledger_depth = 0
  ; work_delay = 0
  ; block_window_duration_ms = 0
  ; transaction_capacity = Log_2 0
  ; pending_coinbase_depth = 0
  ; coinbase_amount = Unsigned.UInt64.of_int 0
  ; supercharged_coinbase_factor = 0
  ; account_creation_fee = Unsigned.UInt64.of_int 0
  ; fork = None
  }

let test () =
  let t11 = Sys.time () in
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:8 ~override_wrap_domain:N2 ~name:"chunked_circuits"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                (* Remember that each of these counts for *half* a row, so we
                   need 2^17 of them to fill 2^16 columns.
                *)
                for _ = 0 to 1 lsl 19 do
                  ignore (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
                done ;
                (* We must now appease the permutation argument gods, to ensure
                   that the 7th permuted column has polynomial degree larger
                   than 2^16, and thus that its high chunks are non-zero.
                   Suckiness of linearization strikes again!
                *)
                let fresh_zero = fresh_zero () in
                Impl.assert_
                  { basic =
                      Kimchi_backend_common.Plonk_constraint_system
                      .Plonk_constraint
                      .T
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
                           } )
                  ; annotation = Some __LOC__
                  } ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
      ()
  in
  Printf.printf "compile time: %fs\n" ((Sys.time () -. t11) /. 10.0) ;

  let module Proof = (val proof) in
  let test_prove () =
    let t1 = Sys.time () in
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Printf.printf "Proving time: %fs\n" ((Sys.time () -. t1) /. 10.0) ;
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) )
  in
  test_prove ()

let () =
  let t = Sys.time () in
  test () ;
  Printf.printf "Execution time: %fs\n" ((Sys.time () -. t) /. 10.0)
