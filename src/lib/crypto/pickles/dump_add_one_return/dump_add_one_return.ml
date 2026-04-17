(** Standalone runner that exercises Add_one_return.
 *
 *  Verbatim translation of the inductive rule from
 *  `mina/src/lib/crypto/pickles/test/test_no_sideloaded.ml:431-470` —
 *  Input_and_output (Field.typ, Field.typ), N=0 max_proofs_verified,
 *  rule [output = input + 1]. No recursion, no chain iteration, so the
 *  trace file produced by `Pickles_trace` contains only the entries
 *  for the single step proof.
 *
 *  This is the simplest possible Output-mode target for byte-identity
 *  validation. Unlike Simple_chain (Input mode, N=1), Add_one_return
 *  forces the kimchi public-input region to include BOTH the input
 *  fields AND the output fields, exercising the positional layout
 *  machinery that distinguishes Input / Output / Input_and_output.
 *
 *  Required env vars at runtime:
 *  - `PICKLES_TRACE_FILE` — path to write the trace log (overwritten).
 *  - `KIMCHI_DETERMINISTIC_SEED` — u64 seed for the patched ChaCha20Rng
 *    in kimchi-stubs. Required (panics if unset) so the proof is
 *    bit-identical across runs and across PureScript.
 *)

open Backend
open Pickles_types

(* URS info — required before any Pickles.compile call. Mirrors
 * dump_simple_chain.ml. *)
let () = Pickles.Backend.Tock.Keypair.set_urs_info []
let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise ()
      ~public_input:
        (Input_and_output (Impls.Step.Field.typ, Impls.Step.Field.typ))
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N0)
      ~name:"blockchain-snark"
      ~choices:(fun ~self:_ ->
        [ { identifier = "main"
          ; prevs = []
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = x } ->
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements = []
                  ; public_output = Impls.Step.Field.(add one x)
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  Pickles.Pickles_trace.string "add_one_return.begin" "step_only" ;
  let input = Tick.Field.of_int 42 in
  let res, (), b0 =
    Promise.block_on_async_exn (fun () -> step input)
  in
  assert (Tick.Field.(equal (of_int 43) res)) ;
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ ((input, res), b0) ] ) ) ;
  Pickles.Pickles_trace.string "add_one_return.end" "verified"
