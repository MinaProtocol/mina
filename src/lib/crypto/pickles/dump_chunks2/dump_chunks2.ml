(** Standalone CS-dump driver for `~num_chunks:2`.
 *
 *  Verbatim translation of the application circuit in
 *  `mina/src/lib/crypto/pickles/test/chunked_circuits/chunks2.ml` —
 *  same N0 single-rule compile, same ~num_chunks:2 ~override_wrap_domain:N1,
 *  same body (2^17 Field.mul fillers + one 7-cell Raw Generic gate to
 *  ensure the 7th permuted column has high-chunks non-zero).
 *
 *  Run with `PICKLES_STEP_CS_DUMP=<stem_template>` /
 *  `PICKLES_WRAP_CS_DUMP=<stem_template>` (where `%c` is a monotonic
 *  counter) to capture the step + wrap CSes that the production
 *  `compile_promise` constructs. The prove step is skipped here — we
 *  only need the CS, which is written DURING compile.
 *
 *  Required env vars:
 *  - `KIMCHI_DETERMINISTIC_SEED` — u64 seed for the patched ChaCha20Rng.
 *  - `PICKLES_STEP_CS_DUMP` / `PICKLES_WRAP_CS_DUMP` — optional fixture
 *    dump paths (stem template, `%c` substituted with monotonic counter).
 *)

open Core_kernel
open Pickles_types
open Pickles.Impls.Step

(* URS info — required before any Pickles.compile call. *)
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () =
  let _tag, _cache_handle, _p, Pickles.Provers.[ prove ] =
    Pickles.compile_promise ()
      ~public_input:(Pickles.Inductive_rule.Input Typ.unit)
      ~auxiliary_typ:Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~num_chunks:2
      ~override_wrap_domain:Pickles_base.Proofs_verified.N1
      ~name:"chunks2"
      ~choices:(fun ~self:_ ->
        [ { identifier = "2^16"
          ; prevs = []
          ; main =
              (fun _ ->
                let fresh_zero () =
                  exists Field.typ ~compute:(fun _ -> Field.Constant.zero)
                in
                (* Each Field.mul counts for half a row, so 2^17 calls
                 * fill 2^16 rows. *)
                for _ = 0 to 1 lsl 17 do
                  ignore (Field.mul (fresh_zero ()) (fresh_zero ()) : Field.t)
                done ;
                (* Force the 7th permuted column's polynomial degree
                 * above 2^16, so its high chunks are non-zero. *)
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
  (* Force compile to complete (CS dumps fire during prove init), then
   * tolerate prove errors — we only care about the CS files. *)
  ( try
      let (), (), _proof =
        Promise.block_on_async_exn (fun () -> prove ())
      in
      ()
    with _ -> () )
