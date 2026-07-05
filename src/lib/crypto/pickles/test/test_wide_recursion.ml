(* Fan-in-4, depth-7 recursion: a Mina-scan-state-shaped tree.

   A single [max_proofs_verified = 4] self-recursive circuit. Its one branch
   verifies four sub-proofs; the leaf is the base case (public input 0), where
   the sub-proofs are dummies gated off by [proof_must_verify = false]. Each
   subsequent layer [k] (public input [k]) merges four copies of the layer-[k-1]
   proof.

   We build a depth-7 chain, reusing the same sub-proof four times at each
   layer, which models a full 4^7 = 16384-transaction tree while only proving
   eight proofs total.

   Fan-in 4 is the largest self-recursive merge width supported: merging its own
   width-w proofs makes the step circuit large enough that at w = 5 (and above)
   it chunks, pushing the wrap circuit to domain 16 > the 2^15 ceiling
   ([Backend.Tock.Rounds.Wrap = Nat.N15]). So a fan-in-5-or-6 self-recursive
   tree is not achievable without chunking. (Verifying narrower proofs is fine:
   a width-6 circuit verifying width-0 leaves fits in domain 15 -- see
   [Tree_proof_n6] in test_no_sideloaded -- but the *merges* here verify
   same-width proofs, which is the demanding case.)

   Run with [PICKLES_PROFILING=1] to print per-proof / per-layer timing. *)

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

module SC = Pickles.Scalar_challenge
open Impls.Step

(* Currently, a circuit must have at least 1 of every type of constraint. *)
let dummy_constraints () =
  Impl.(
    let x = exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3) in
    let g =
      exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
          Pickles.Backend.Tick.Inner_curve.(to_affine_exn one) )
    in
    ignore
      ( SC.to_field_checked'
          (module Impl)
          ~num_bits:16
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t * Field.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_main_inputs.Ops.scale_fast g ~num_bits:5 (Shifted_value x)
        : Step_main_inputs.Inner_curve.t ) ;
    ignore
      ( Step_verifier.Scalar_challenge.endo g ~num_bits:4
          (Kimchi_backend_common.Scalar_challenge.create x)
        : Field.t * Field.t ))

module Merge_4 = struct
  type _ Snarky_backendless.Request.t +=
    | Sub_proof :
        Pickles_types.Nat.N4.n Pickles.Proof.t Snarky_backendless.Request.t

  let handler (proof : _ Pickles.Proof.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Sub_proof ->
        respond (Provide proof)
    | _ ->
        respond Unhandled

  let _tag, _, p, Provers.[ merge ] =
    Common.time "compile merge-4" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Pickles_types.Nat.N4)
          ~name:"merge-4"
          ~choices:(fun ~self ->
            [ { identifier = "merge"
              ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
              ; prevs = [ self; self; self; self ]
              ; main =
                  (fun { public_input = self_input } ->
                    dummy_constraints () ;
                    (* Leaf (base case) when the public input is 0; otherwise a
                       merge of four layer-[self_input - 1] proofs. *)
                    let is_base_case = Field.equal Field.zero self_input in
                    let proof_must_verify = Boolean.not is_base_case in
                    let prev_input = Field.(self_input - one) in
                    let sub () =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Sub_proof )
                    in
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = prev_input
                            ; proof = sub ()
                            ; proof_must_verify
                            }
                          ; { public_input = prev_input
                            ; proof = sub ()
                            ; proof_must_verify
                            }
                          ; { public_input = prev_input
                            ; proof = sub ()
                            ; proof_must_verify
                            }
                          ; { public_input = prev_input
                            ; proof = sub ()
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
  let open Merge_4 in
  let depth = 7 in
  (* Layer 0: the leaf / base case, whose four sub-proofs are dummies. *)
  let dummy : Pickles_types.Nat.N4.n Pickles.Proof.t =
    Pickles.Proof.dummy Pickles_types.Nat.N4.n Pickles_types.Nat.N4.n
      ~domain_log2:16
  in
  let (), (), leaf =
    Common.time "prove layer 0 (leaf)" (fun () ->
        Promise.block_on_async_exn (fun () ->
            merge ~handler:(handler dummy) Field.Constant.zero ) )
  in
  (* Layers 1..depth: each merges four copies of the previous layer's proof. *)
  let rec go layer prev =
    if layer > depth then prev
    else
      let (), (), merged =
        Common.time (Printf.sprintf "prove layer %d (merge of 4)" layer)
          (fun () ->
            Promise.block_on_async_exn (fun () ->
                merge ~handler:(handler prev) (Field.Constant.of_int layer) ) )
      in
      go (layer + 1) merged
  in
  let root = go 1 leaf in
  Common.time "verify root" (fun () ->
      Or_error.ok_exn
        (Promise.block_on_async_exn (fun () ->
             Proof.verify_promise [ (Field.Constant.of_int depth, root) ] ) ) ) ;
  Printf.printf
    "width-4 depth-%d tree: proved and verified the root (models 4^%d = %d \
     transactions)\n\
     %!"
    depth depth (Int.pow 4 depth)
