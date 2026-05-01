(** Standalone reference for Pickles side-loaded recursion.
 *
 *  This is a verbatim lift of the side-loaded `Simple_chain` example
 *  from `mina/src/lib/crypto/pickles/pickles.ml:1479-1718` (the
 *  `let%test_module "domain too small"` block) into a standalone
 *  executable, so we can run it under `dune exec` and add CS / witness
 *  dumping in follow-up steps via the existing dump infrastructure.
 *
 *  Shape:
 *    - Child = `No_recursion` (mpv = N0, public input Field, asserts
 *      `self = 0`).
 *    - Side-loaded tag with `max_proofs_verified = N2` (the side-tag's
 *      upper bound; the actual child has mpv N0).
 *    - Main = `Simple_chain` (mpv = N1, public input Field) whose
 *      single `prevs` slot is the side-loaded tag. Inside main we
 *      `exists` the VK as a prover-value, bind it via
 *      `Side_loaded.in_prover` (deferred via `as_prover`) and
 *      `Side_loaded.in_circuit`, and assert the increment relation
 *      `prev + 1 = self`.
 *    - Drives one proof: `step Field.Constant.one` with handler
 *      providing (prev_input = 0, child b0 wrapped via
 *      `Side_loaded.Proof.of_proof`, child's side-loaded VK).
 *)

open Pickles
open Pickles_types
open Impls.Step

let () = Backend.Tock.Keypair.set_urs_info []
let () = Backend.Tick.Keypair.set_urs_info []

(* Currently, a circuit must have at least 1 of every type of
   constraint. Mirrors `pickles.ml:1483-1508`. *)
let dummy_constraints () =
  Impl.(
    let x =
      exists Field.typ ~compute:(fun () -> Field.Constant.of_int 3)
    in
    let g =
      exists Step_main_inputs.Inner_curve.typ ~compute:(fun _ ->
          Backend.Tick.Inner_curve.(to_affine_exn one) )
    in
    ignore
      ( Scalar_challenge.to_field_checked'
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

module No_recursion = struct
  let tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N0)
          ~name:"side_loaded_child__no_recursion"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = []
              ; feature_flags = Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    dummy_constraints () ;
                    Field.Assert.equal self Field.zero ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements = []
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example =
    let (), (), b0 =
      Common.time "b0" (fun () ->
          Promise.block_on_async_exn (fun () -> step Field.Constant.zero) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.zero, b0) ] ) ) ;
    (Field.Constant.zero, b0)

  let example_input, example_proof = example
end

module Simple_chain = struct
  type _ Snarky_backendless.Request.t +=
    | Prev_input : Field.Constant.t Snarky_backendless.Request.t
    | Proof : Side_loaded.Proof.t Snarky_backendless.Request.t
    | Verifier_index :
        Side_loaded.Verification_key.t Snarky_backendless.Request.t

  let handler (prev_input : Field.Constant.t) (proof : _ Proof.t)
      (verifier_index : Side_loaded.Verification_key.t)
      (Snarky_backendless.Request.With { request; respond }) =
    match request with
    | Prev_input ->
        respond (Provide prev_input)
    | Proof ->
        respond (Provide proof)
    | Verifier_index ->
        respond (Provide verifier_index)
    | _ ->
        respond Unhandled

  let side_loaded_tag =
    Side_loaded.create ~name:"foo"
      ~max_proofs_verified:(Nat.Add.create Nat.N2.n)
      ~feature_flags:Plonk_types.Features.none ~typ:Field.typ

  let _tag, _, p, Provers.[ step ] =
    Common.time "compile" (fun () ->
        compile_promise () ~public_input:(Input Field.typ)
          ~auxiliary_typ:Typ.unit
          ~max_proofs_verified:(module Nat.N1)
          ~name:"side_loaded_main__simple_chain"
          ~choices:(fun ~self:_ ->
            [ { identifier = "main"
              ; prevs = [ side_loaded_tag ]
              ; feature_flags = Plonk_types.Features.none_bool
              ; main =
                  (fun { public_input = self } ->
                    let prev =
                      exists Field.typ ~request:(fun () -> Prev_input)
                    in
                    let proof =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Proof )
                    in
                    let vk =
                      exists (Typ.prover_value ()) ~request:(fun () ->
                          Verifier_index )
                    in
                    as_prover (fun () ->
                        let vk =
                          As_prover.read (Typ.prover_value ()) vk
                        in
                        Side_loaded.in_prover side_loaded_tag vk ) ;
                    let vk =
                      exists Side_loaded.Verification_key.typ
                        ~compute:(fun () ->
                          As_prover.read (Typ.prover_value ()) vk )
                    in
                    Side_loaded.in_circuit side_loaded_tag vk ;
                    let is_base_case = Field.equal Field.zero self in
                    let self_correct = Field.(equal (one + prev) self) in
                    Boolean.Assert.any [ self_correct; is_base_case ] ;
                    Promise.return
                      { Inductive_rule.previous_proof_statements =
                          [ { public_input = prev
                            ; proof
                            ; proof_must_verify = Boolean.true_
                            }
                          ]
                      ; public_output = ()
                      ; auxiliary_output = ()
                      } )
              }
            ] ) )

  module Proof = (val p)

  let example1 =
    let (), (), b1 =
      Common.time "b1" (fun () ->
          Promise.block_on_async_exn (fun () ->
              let%bind.Promise vk =
                Side_loaded.Verification_key.of_compiled_promise No_recursion.tag
              in
              step
                ~handler:
                  (handler No_recursion.example_input
                     (Side_loaded.Proof.of_proof No_recursion.example_proof)
                     vk )
                Field.Constant.one ) )
    in
    Or_error.ok_exn
      (Promise.block_on_async_exn (fun () ->
           Proof.verify_promise [ (Field.Constant.one, b1) ] ) ) ;
    (Field.Constant.one, b1)
end

let () =
  let _ = Simple_chain.example1 in
  Format.printf "side-loaded main verified.@."
