(** CS-dump driver for `~num_chunks:8`.
 *  Variant of `dump_chunks2.ml` — `chunks8.ml` test's application body.
 *  Note: chunks8 uses `override_wrap_domain:N2` (vs N1 for chunks2/4). *)

open Core_kernel
open Pickles_types
open Pickles.Impls.Step

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () =
  let _tag, _cache_handle, _p, Pickles.Provers.[ prove ] =
    Pickles.compile_promise ()
      ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:8
      ~override_wrap_domain:Pickles_base.Proofs_verified.N2
      ~name:"chunks8"
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^18"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                for _ = 0 to 1 lsl 19 do
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
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements = []
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
          }
        ] )
  in
  ( try
      let (), (), _proof =
        Promise.block_on_async_exn (fun () -> prove ())
      in
      ()
    with _ -> () )
