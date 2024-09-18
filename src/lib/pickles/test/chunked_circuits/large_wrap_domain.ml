(*
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

(* Fails with:
    "This circuit was compiled for proofs using the wrap domain of size 14, but the actual wrap domain size for the circuit has size 16. You should pass the ~override_wrap_domain argument to set the correct domain size.")
   ("Raised at Stdlib.failwith in file \"stdlib.ml\", line 29, characters 17-33"
    "Called from Pickles__Compile.Make.compile.(fun) in file \"src/lib/pickles/compile.ml\", line 726, characters 17-414"
    *)
let test () =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~branches:(module Nat.N1)
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:16 ~override_wrap_domain:N2 ~name:"chunked_circuits"
      ~constraint_constants (* TODO(mrmr1993): This was misguided.. Delete. *)
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^19"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                (* Remember that each of these counts for *half* a row, so we
                   need 2^20 of them to fill 2^19 rows.
                *)
                for _ = 0 to 1 lsl 20 do
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

  let module Proof = (val proof) in
  let test_prove () =
    let public_input, (), proof =
      Async.Thread_safe.block_on_async_exn (fun () -> prove ())
    in
    Or_error.ok_exn
      (Async.Thread_safe.block_on_async_exn (fun () ->
           Proof.verify [ (public_input, proof) ] ) )
  in
  test_prove ()

let () =
  test () ;
  Alcotest.run "Chunked circuit"
    [ ("2^19", [ ("prove and verify", `Quick, test) ]) ]
*)
