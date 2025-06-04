open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let t0 = Sys.time ()

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let _test lazy_mode =
  let _tag, _cache_handle, proof, Pickles.Provers.[ prove ] =
    Pickles.compile ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~lazy_mode ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:2 ~override_wrap_domain:N1 ~name:"lazy_mode"
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh num =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.of_int num)
                in
                for i = 0 to 1 lsl 16 do
                  let left = fresh i in
                  let right = fresh (i + 1) in
                  let mul = (Field.mul left right : Field.t) in
                  Impl.assert_
                    (Raw
                       { kind = Generic
                       ; values =
                           [| left
                            ; right
                            ; mul
                            ; fresh 0
                            ; fresh 0
                            ; fresh 0
                            ; fresh 0
                           |]
                       ; coeffs = [||]
                       } )
                done ;
                { previous_proof_statements = []
                ; public_output = ()
                ; auxiliary_output = ()
                } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
      ()
  in

  Printf.printf "compile time: %fs\n" ((Sys.time () -. t0) /. 10.0) ;

  let module Proof = (val proof) in
  Format.printf "calling prove (1) \n" ;
  let t1 = Sys.time () in
  let _ = Async.Thread_safe.block_on_async (fun () -> prove ()) in
  Printf.printf "prove time: %fs\n" ((Sys.time () -. t1) /. 10.0) ;

  ()

let () =
  let is_lazy = match Sys.argv.(1) with "lazy" -> true | _ -> false in
  print_endline ("running lazy_mode: " ^ Bool.to_string is_lazy) ;
  _test is_lazy
