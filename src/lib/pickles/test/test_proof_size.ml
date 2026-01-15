(* Testing
   -------

   Component: Pickles
   Subject: Regression test for proof and verification key sizes
   Invocation: \
    dune exec src/lib/pickles/test/test_proof_size.exe

   This is a regression test that verifies Pickles proof sizes don't change
   unexpectedly. If the proof format changes intentionally, update the
   expected sizes below.
*)

module SC = Pickles.Scalar_challenge

let () = Pickles.Backend.Tock.Keypair.set_urs_info []

let () = Pickles.Backend.Tick.Keypair.set_urs_info []

let () = Backtrace.elide := false

open Impls.Step

let () = Snarky_backendless.Snark0.set_eval_constraints true

(* ============================================================ *)
(* EXPECTED SIZES - Update these if proof format changes        *)
(* ============================================================ *)

(** Expected binary size for N2 proofs (2 predecessors).
    This is the typical configuration for Mina blockchain proofs. *)
let expected_n2_proof_binary_size = 9088

(** Expected binary size for side-loaded verification keys. *)
let expected_side_loaded_vk_binary_size = 3566

(** Tolerance for size comparison (in bytes).
    Small variations may occur due to serialization details. *)
let size_tolerance = 100

(* ============================================================ *)

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

(* Request types for recursive proofs *)
type _ Snarky_backendless.Request.t +=
  | Prev_input : Field.Constant.t Snarky_backendless.Request.t
  | Prev_proof : Pickles_types.Nat.N2.n Proof.t Snarky_backendless.Request.t

let handler (prev_input : Field.Constant.t)
    (prev_proof : Pickles_types.Nat.N2.n Proof.t)
    (Snarky_backendless.Request.With { request; respond }) =
  match request with
  | Prev_input ->
      respond (Provide prev_input)
  | Prev_proof ->
      respond (Provide prev_proof)
  | _ ->
      respond Unhandled

(* Compile proof system with N2 (supports up to 2 predecessor proofs) *)
let tag, _, p, Provers.[ base_step; recursive_step ] =
  Common.time "compile" (fun () ->
      compile_promise () ~public_input:(Input Field.typ) ~auxiliary_typ:Typ.unit
        ~max_proofs_verified:(module Pickles_types.Nat.N2)
        ~name:"test-proof-size"
        ~choices:(fun ~self ->
          [ (* Base case: no predecessors *)
            { identifier = "base"
            ; prevs = []
            ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
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
          ; (* Recursive case: 1 predecessor *)
            { identifier = "recursive"
            ; prevs = [ self ]
            ; feature_flags = Pickles_types.Plonk_types.Features.none_bool
            ; main =
                (fun { public_input = self } ->
                  dummy_constraints () ;
                  let prev_input =
                    exists Field.typ ~request:(fun () -> Prev_input)
                  in
                  let prev_proof =
                    exists (Typ.prover_value ()) ~request:(fun () -> Prev_proof)
                  in
                  let new_value = Field.(self - prev_input) in
                  Field.Assert.equal new_value Field.one ;
                  Promise.return
                    { Inductive_rule.previous_proof_statements =
                        [ { public_input = prev_input
                          ; proof = prev_proof
                          ; proof_must_verify = Boolean.true_
                          }
                        ]
                    ; public_output = ()
                    ; auxiliary_output = ()
                    } )
            }
          ] ) )

module Proof = (val p)

let generate_base_proof () =
  let (), (), proof =
    Common.time "generate base proof" (fun () ->
        Promise.block_on_async_exn (fun () -> base_step Field.Constant.zero) )
  in
  proof

let generate_recursive_proof prev_input prev_proof =
  let new_input = Field.Constant.(prev_input + one) in
  let (), (), proof =
    Common.time "generate recursive proof" (fun () ->
        Promise.block_on_async_exn (fun () ->
            recursive_step ~handler:(handler prev_input prev_proof) new_input ) )
  in
  proof

(** Measure binary size of a proof using Binable *)
let measure_proof_binary_size proof =
  let binary =
    Binable.to_string (module Pickles.Proof.Proofs_verified_2.Stable.V2) proof
  in
  String.length binary

(** Measure binary size of a side-loaded verification key *)
let measure_vk_binary_size vk =
  let binary =
    Binable.to_string (module Side_loaded.Verification_key.Stable.V2) vk
  in
  String.length binary

let test_proof_size () =
  (* Generate a recursive proof - this is the typical case *)
  let base_proof = generate_base_proof () in
  let recursive_proof =
    generate_recursive_proof Field.Constant.zero base_proof
  in
  let actual_size = measure_proof_binary_size recursive_proof in
  Fmt.pr "N2 recursive proof binary size: %d bytes@." actual_size ;
  Fmt.pr "Expected size: %d bytes (±%d)@." expected_n2_proof_binary_size
    size_tolerance ;
  let diff = abs (actual_size - expected_n2_proof_binary_size) in
  if diff > size_tolerance then
    Alcotest.failf
      "Proof size changed! Expected %d bytes, got %d bytes (diff: %d).@.\
       If this is intentional, update expected_n2_proof_binary_size in \
       test_proof_size.ml"
      expected_n2_proof_binary_size actual_size diff ;
  Fmt.pr "✓ Proof size matches expected value@."

let test_vk_size () =
  let vk =
    Promise.block_on_async_exn (fun () ->
        Side_loaded.Verification_key.of_compiled_promise tag )
  in
  let actual_size = measure_vk_binary_size vk in
  Fmt.pr "Side-loaded VK binary size: %d bytes@." actual_size ;
  Fmt.pr "Expected size: %d bytes (±%d)@." expected_side_loaded_vk_binary_size
    size_tolerance ;
  let diff = abs (actual_size - expected_side_loaded_vk_binary_size) in
  if diff > size_tolerance then
    Alcotest.failf
      "VK size changed! Expected %d bytes, got %d bytes (diff: %d).@.\
       If this is intentional, update expected_side_loaded_vk_binary_size in \
       test_proof_size.ml"
      expected_side_loaded_vk_binary_size actual_size diff ;
  Fmt.pr "✓ Verification key size matches expected value@."

let test_proof_size_constant_across_depths () =
  (* Verify that proof size doesn't grow with recursion depth *)
  let base_proof = generate_base_proof () in
  let depth1_proof =
    generate_recursive_proof Field.Constant.zero base_proof
  in
  let depth2_proof =
    generate_recursive_proof Field.Constant.one depth1_proof
  in
  let size1 = measure_proof_binary_size depth1_proof in
  let size2 = measure_proof_binary_size depth2_proof in
  Fmt.pr "Proof size at depth 1: %d bytes@." size1 ;
  Fmt.pr "Proof size at depth 2: %d bytes@." size2 ;
  if size1 <> size2 then
    Alcotest.failf
      "Proof size not constant across recursion depths! depth1=%d, depth2=%d"
      size1 size2 ;
  Fmt.pr "✓ Proof size is constant across recursion depths@."

let () =
  Fmt.pr "@.=== Proof Size Regression Tests ===@.@." ;
  let open Alcotest in
  run "Proof Size Regression"
    [ ( "size"
      , [ test_case "proof binary size" `Slow test_proof_size
        ; test_case "vk binary size" `Slow test_vk_size
        ; test_case "constant across depths" `Slow
            test_proof_size_constant_across_depths
        ] )
    ]
