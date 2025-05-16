open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let _test lazy_mode =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~lazy_mode ~auxiliary_typ:Typ.unit
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

  let module Proof = (val proof) in
  Format.printf "calling prove (1) \n" ;
  let _ = Async.Thread_safe.block_on_async (fun () -> prove ()) in

  Format.printf "calling prove (2) \n" ;
  let _ = Async.Thread_safe.block_on_async (fun () -> prove ()) in
  ()

let () =
  let is_lazy = match Sys.argv.(1) with "lazy" -> true | _ -> false in
  print_endline ("running lazy_mode: " ^ Bool.to_string is_lazy) ;
  _test is_lazy
