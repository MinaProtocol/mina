(* Executable demonstrating a Simple_chain recursive proof with a
   parameterized initial state.

   The public input of each proof is a pair [(initial, current)]. The base
   case requires [current = initial] (so any anchor works, not just zero).
   Every recursive step asserts both [prev_current + 1 = current] and
   [prev_initial = initial], so the anchor is carried through the chain and
   cannot be rewritten. *)

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Core_kernel.Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input :
        (Field.Constant.t * Field.Constant.t) Snarky_backendless.Request.t
    | Proof : Pickles_types.Nat.N1.n Proof.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t * Field.Constant.t)
      (proof : _ Proof.t) (Snarky_backendless.Request.With { request; respond })
      =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise ()
          ~public_input:(Input (Typ.tuple2 Field.typ Field.typ))
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N1)
          ~name:"blockchain-snark"
          ~choices:(fun ~self ->
            [ { identifier = "main"
              ; prevs = [ self ]
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = initial, current } ->
                    let prev_initial, prev_current =
                      exists (Typ.tuple2 Field.typ Field.typ)
                        ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () -> Proof)
                    in
                    let is_base_case = Field.equal current initial in
                    let proof_must_verify = Boolean.not is_base_case in
                    let step_ok = Field.(equal (one + prev_current) current) in
                    let carry_ok = Field.equal prev_initial initial in
                    Boolean.Assert.any [ step_ok; is_base_case ] ;
                    Boolean.Assert.any [ carry_ok; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = (prev_initial, prev_current)
                            ; proof
                            ; proof_must_verify
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)
end

let () =
  let initial = Field.Constant.of_int 41 in
  let next = Field.Constant.of_int 42 in

  (* Base case: (initial=41, current=41). The previous-proof slot is a dummy
     that is not required to verify, because [current = initial] here. *)
  let dummy_prev_input =
    (Field.Constant.(negate one), Field.Constant.(negate one))
  in
  let dummy_prev_proof : Pickles_types.Nat.N1.n Pickles.Proof.t =
    Pickles.Proof.dummy Pickles_types.Nat.N1.n Pickles_types.Nat.N1.n
      ~domain_log2:14
  in
  let (), (), b0 =
    Common.time "b0" (fun () ->
        Promise.block_on_async_exn (fun () ->
            Simple_chain.step
              ~handler:(Simple_chain.handler dummy_prev_input dummy_prev_proof)
              (initial, initial) ) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Simple_chain.Proof.verify_promise [ ((initial, initial), b0) ] ) ) ;
  Format.printf "base-case proof verified, (initial, current) = (41, 41)@." ;

  (* Recursive step: (initial=41, current=42), prev = (41, 41) with proof b0. *)
  let (), (), b1 =
    Common.time "b1" (fun () ->
        Promise.block_on_async_exn (fun () ->
            Simple_chain.step
              ~handler:(Simple_chain.handler (initial, initial) b0)
              (initial, next) ) )
  in
  Or_error.ok_exn
    (Promise.block_on_async_exn (fun () ->
         Simple_chain.Proof.verify_promise [ ((initial, next), b1) ] ) ) ;
  Format.printf "recursive proof verified, (initial, current) = (41, 42)@."
