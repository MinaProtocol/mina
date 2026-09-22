(** The self-recursive chain at two chunks: `dump_simple_chain`'s
 *  `self = prev + 1` rule with a body that fills 2^16 rows, compiled at
 *  `~num_chunks:2`, proved at the base case and at one inductive step.
 *
 *  The base case's dummy prev carries its evaluations at two chunks
 *  (`Proof.dummy ~num_chunks:2`); b1 then verifies b0, the first proof of
 *  a chunked self-recursive chain. Run with `KIMCHI_WITNESS_DUMP` set,
 *  the four witnesses (b0 step, b0 wrap, b1 step, b1 wrap) are what
 *  `tools/witness_diff.sh self_recursive_chunks` compares against the
 *  PureScript `SelfRecursiveChunks` test.
 *)

open Backend
open Pickles_types

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

type _ Snarky_backendless.Request.t +=
  | Prev_input : Tick.Field.t Snarky_backendless.Request.t
  | Proof : Pickles_types.Nat.N1.n Pickles.Proof.t Snarky_backendless.Request.t

let handler (prev_input : Tick.Field.t) (proof : _ Pickles.Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev_input ->
      respond (Provide prev_input)
  | Proof ->
      respond (Provide proof)
  | _ ->
      respond Unhandled

let () =
  let _tag, _, p, Pickles.Provers.[ step ] =
    Pickles.compile_promise () ~public_input:(Input Impls.Step.Field.typ)
      ~auxiliary_typ:Impls.Step.Typ.unit
      ~max_proofs_verified:(module Nat.N1)
      ~num_chunks:2 ~name:"self-recursive-chunks"
      ~choices:(fun ~self ->
        [ { identifier = "main"
          ; prevs = [ self ]
          ; feature_flags = Plonk_types.Features.none_bool
          ; main =
              (fun { public_input = self } ->
                let prev =
                  Impls.Step.exists Impls.Step.Field.typ ~request:(fun () ->
                      Prev_input )
                in
                let proof =
                  Impls.Step.exists (Impls.Step.Typ.prover_value ())
                    ~request:(fun () -> Proof)
                in
                let is_base_case =
                  Impls.Step.Field.equal Impls.Step.Field.zero self
                in
                let proof_must_verify = Impls.Step.Boolean.not is_base_case in
                let self_correct = Impls.Step.Field.(equal (one + prev) self) in
                Impls.Step.Boolean.Assert.any [ self_correct; is_base_case ] ;
                (* Each multiplication is half a row: 2^17 of them fill 2^16
                   rows. The 7-wire generic pushes the 7th permuted column's
                   degree past 2^16, so its high chunk is non-zero. *)
                let fresh_zero () =
                  Impls.Step.exists Impls.Step.Field.typ ~compute:(fun _ ->
                      Impls.Step.Field.Constant.zero )
                in
                for _ = 0 to 1 lsl 17 do
                  ignore
                    ( Impls.Step.Field.mul (fresh_zero ()) (fresh_zero ())
                      : Impls.Step.Field.t )
                done ;
                let z = fresh_zero () in
                Impls.Step.assert_
                  (Raw
                     { kind = Generic
                     ; values = [| z; z; z; z; z; z; z |]
                     ; coeffs = [||]
                     } ) ;
                Promise.return
                  { Pickles.Inductive_rule.previous_proof_statements =
                      [ { public_input = prev; proof; proof_must_verify } ]
                  ; public_output = ()
                  ; auxiliary_output = ()
                  } )
          }
        ] )
  in
  let module Proof = (val p) in
  let s_neg_one = Tick.Field.(negate one) in
  let b_neg_one : Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy ~num_chunks:2 Nat.N1.n Nat.N1.n ~domain_log2:17
  in
  let (), (), b0 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler s_neg_one b_neg_one) Tick.Field.zero )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.zero, b0) ] ) ) ;
  let (), (), b1 =
    Promise.block_on_async_exn (fun () ->
        step ~handler:(handler Tick.Field.zero b0) Tick.Field.one )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Proof.verify_promise [ (Tick.Field.one, b1) ] ) ) ;
  print_endline "self_recursive_chunks: b0 and b1 proved and verified"
