(* Testing
   -------

   Component: Pickles
   Subject: Test Wrap
   Invocation: \
    dune exec src/lib/pickles/test/main.exe -- test "Gate:"
*)
open Pickles_types
module Wrap = Pickles__Wrap
module Import = Pickles__Import

type test_options =
  { true_is_yes : Plonk_types.Features.options
  ; true_is_maybe : Plonk_types.Features.options
  ; all_maybes : Plonk_types.Features.options
  }

(* Helper function to convert actual feature flags into 3 test configurations of feature flags
     @param actual_feature_flags The actual feature flags in terms of true/false

     @return Corresponding feature flags configs composed of Yes/No/Maybe options
     - one where true is mapped to Yes and false is mapped to No
     - one where true is mapped to Maybe and false is mapped to No
     - one where true and false are both mapped to Maybe *)
let generate_test_feature_flag_configs
    (actual_feature_flags : Plonk_types.Features.flags) : test_options =
  (* Set up a helper to convert actual feature flags composed of booleans into
     feature flags composed of Yes/No/Maybe options.
     @param actual_feature_flags The actual feature flags in terms of true/false
     @param true_opt  Opt type to use for true/enabled features
     @param false_opt Opt type to use for false/disabled features
     @return Corresponding feature flags composed of Yes/No/Maybe values *)
  let compute_feature_flags (actual_feature_flags : Plonk_types.Features.flags)
      (true_opt : Opt.Flag.t) (false_opt : Opt.Flag.t) :
      Plonk_types.Features.options =
    Plonk_types.Features.map actual_feature_flags ~f:(function
      | true ->
          true_opt
      | false ->
          false_opt )
  in

  (* Generate the 3 configurations of the actual feature flags using
     helper *)
  let open Opt.Flag in
  { true_is_yes = compute_feature_flags actual_feature_flags Yes No
  ; true_is_maybe = compute_feature_flags actual_feature_flags Maybe No
  ; all_maybes = compute_feature_flags actual_feature_flags Maybe Maybe
  }

(* Run the recursive proof tests on the supplied inputs.

   @param actual_feature_flags User-specified feature flags, matching those
   required by the backend circuit
   @param public_input list of public inputs (can be empty)
   @param vk Verifier index for backend circuit
   @param proof Backend proof

   @return true or throws and exception
*)
let run_recursive_proof_test (actual_feature_flags : Plonk_types.Features.flags)
    (feature_flags : Plonk_types.Features.options)
    (public_input : Pasta_bindings.Fp.t list)
    (vk : Kimchi_bindings.Protocol.VerifierIndex.Fp.t)
    (proof : Backend.Tick.Proof.with_public_evals) : Impls.Step.Boolean.value =
  (* Constants helper - takes an OCaml value and converts it to a snarky value, where
                        all values here are constant literals.  N.b. this should be
                        encapsulated as Snarky internals, but it never got merged. *)
  let constant (Typ typ : _ Snarky_backendless.Typ.t) x =
    let xs, aux = typ.value_to_fields x in
    typ.var_of_fields (Array.map xs ~f:Impls.Step.Field.constant, aux)
  in

  (* Compute deferred values - in the Pickles recursive proof system, deferred values
     are values from 2 proofs earlier in the recursion hierarchy.  Every recursion
     goes through a two-phase process of step and wrap, like so

       step <- wrap <- step <- ... <- wrap <- step,
          `<-----------'
             deferred

     where there may be multiple children at each level (but let's ignore that!).
     Deferred values are values (part of the public input) that must be passed between
     the two phases in order to be verified correctly-- it works like this.

       - The wrap proof is passed the deferred values for its step proof as part of its public input.
       - The wrap proof starts verifying the step proof.  As part of this verification it must
         perform all of the group element checks (since it's over the Vesta base field); however,
         at this stage it just assumes that the deferred values of its public input are correct
         (i.e. it defers checking them).
       - The next step proof verifies the wrap proof with a similar process, but using the other
         curve (e.g. Pallas).  There are two important things to note:
           - Since it is using the other curve, it can compute the commitments to the public inputs
             of the previous wrap circuit that were passed into it.  In other words, the next step
             proof receives data from the previous wrap proof about the previous step proof.  Yeah,
             from two proofs back! (e.g. the deferred values)
           - The next step proof also computes the deferred values inside the circuit and verifies
             that they match those used by the previous wrap proof.

      The code below generates the deferred values so that we can verifiy that we can actually
      compute those values correctly inside the circuit.  Special thanks to Matthew Ryan for
      explaining this in detail. *)
  let { Wrap.For_tests_only.deferred_values
      ; x_hat_evals
      ; sponge_digest_before_evaluations
      } =
    Wrap.For_tests_only.deferred_values ~actual_feature_flags ~sgs:[]
      ~prev_challenges:[] ~step_vk:vk ~public_input ~proof
      ~actual_proofs_verified:Nat.N0.n
  in

  let full_features =
    Plonk_types.Features.to_full ~or_:Opt.Flag.( ||| ) feature_flags
  in

  (* Define Typ.t for Deferred_values.t -- A Type.t defines how to convert a value of some type
                                          in OCaml into a var in circuit/Snarky.

     This complex function is called with two sets of inputs: once for the step circuit and
     once for the wrap circuit.  It was decided not to use a functor for this. *)
  let deferred_values_typ =
    let open Impls.Step in
    let open Step_main_inputs in
    let open Step_verifier in
    Import.Types.Wrap.Proof_state.Deferred_values.In_circuit.typ
      (module Impls.Step)
      ~feature_flags:full_features ~challenge:Challenge.typ
      ~scalar_challenge:Challenge.typ
      ~dummy_scalar_challenge:
        (Kimchi_backend_common.Scalar_challenge.create
           Limb_vector.Challenge.Constant.zero )
      (Shifted_value.Type1.typ Field.typ)
      (Import.Branch_data.typ
         (module Impl)
         ~assert_16_bits:(Step_verifier.assert_n_bits ~n:16) )
  in

  (* Use deferred_values_typ and the constant helper to prepare deferred_values
     for use in the circuit.  We change some [Opt.t] to [Option.t] because that is
     what Type.t is configured to accept. *)
  let deferred_values =
    constant deferred_values_typ
      { deferred_values with
        plonk =
          { deferred_values.plonk with
            joint_combiner =
              Opt.to_option_unsafe deferred_values.plonk.joint_combiner
          }
      }
  (* Prepare all of the evaluations (i.e. all of the columns in the proof that we open)
     for use in the circuit *)
  and evals =
    constant
      (Plonk_types.All_evals.typ ~num_chunks:1
         (module Impls.Step)
         full_features )
      { evals =
          { public_input = x_hat_evals; evals = proof.proof.openings.evals }
      ; ft_eval1 = proof.proof.openings.ft_eval1
      }
  in

  (* Run the circuit without generating a proof using run_and_check *)
  Impls.Step.run_and_check (fun () ->
      (* Set up the step sponge from the wrap sponge -- we cannot use the same poseidon
         sponge in both step and wrap because they have different fields.

         In order to continue the Fiat-Shamir heuristic across field boundaries we use
         the wrap sponge for everything in the wrap proof, squeeze it one final time and
         expose the squoze value in the public input to the step proof, which absorbs
         said squoze value into the step sponge. :-) This means the step sponge has absorbed
         everything from the proof so far by proxy and that is also over the native field! *)
      let res, _chals =
        let sponge =
          let open Step_main_inputs in
          let sponge = Sponge.create sponge_params in
          Sponge.absorb sponge
            (`Field (Impl.Field.constant sponge_digest_before_evaluations)) ;
          sponge
        in

        (* Call finalisation with all of the required details *)
        Step_verifier.finalize_other_proof
          (module Nat.N0)
          ~step_domains:
            (`Known [ { h = Pow_2_roots_of_unity vk.domain.log_size_of_group } ])
          ~zk_rows:3 ~sponge ~prev_challenges:[] deferred_values evals
      in

      (* Read the boolean result from the circuit and make it available
         to the OCaml world. *)
      Impls.Step.(As_prover.(fun () -> read Boolean.typ res)) )
  |> Or_error.ok_exn

(* Common srs value for all tests *)
let srs =
  Kimchi_bindings.Protocol.SRS.Fp.create (1 lsl Common.Max_degree.step_log2)

type example =
     Kimchi_bindings.Protocol.SRS.Fp.t
  -> Kimchi_bindings.Protocol.Index.Fp.t
     * Pasta_bindings.Fp.t list
     * ( Pasta_bindings.Fq.t Kimchi_types.or_infinity
       , Pasta_bindings.Fp.t )
       Kimchi_types.proof_with_public

module type SETUP = sig
  val example : example

  (* Feature flags tused for backend proof *)
  val actual_feature_flags : bool Plonk_types.Features.t
end

(* [Make] is the test functor.

   Given a test setup, compute different test configurations and define 3
   test for said configurations. *)
module Make (S : SETUP) = struct
  (* Generate foreign field multiplication test backend proof using Kimchi,
     obtaining the proof and corresponding prover index.

     Note: we only want to pay the cost of generating this proof once and
     then reuse it many times for the different recursive proof tests. *)
  let index, public_input, proof = S.example srs

  (* Obtain verifier key from prover index and convert backend proof to
     snarky proof *)
  let vk = Kimchi_bindings.Protocol.VerifierIndex.Fp.create index

  let proof = Backend.Tick.Proof.of_backend_with_public_evals proof

  let test_feature_flags_configs =
    generate_test_feature_flag_configs S.actual_feature_flags

  let runtest feature_flags =
    run_recursive_proof_test S.actual_feature_flags feature_flags public_input
      vk proof

  let test_true_is_yes () =
    assert (runtest test_feature_flags_configs.true_is_yes)

  let test_true_is_maybe () =
    assert (runtest test_feature_flags_configs.true_is_maybe)

  let test_all_maybes () = assert (runtest test_feature_flags_configs.all_maybes)

  let tests =
    let open Alcotest in
    [ test_case "true -> yes" `Quick test_true_is_yes
    ; test_case "true -> maybe" `Quick test_true_is_maybe
    ; test_case "all maybes" `Quick test_all_maybes
    ]
end

(* Small combinators to lift gate example signatures to the expected
   signatures for the tests. This amounts to generating the list of public
   inputs from either no public inputs, a single one or a pair of inputs
   returned by the gate example. *)

let without_public_input gate_example srs =
  let index, proof = gate_example srs in
  (index, [], proof)

let with_one_public_input gate_example srs =
  let index, public_input, proof = gate_example srs in
  (index, [ public_input ], proof)

let with_two_public_inputs gate_example srs =
  let index, (public_input1, public_input2), proof = gate_example srs in
  (index, [ public_input1; public_input2 ], proof)

module Lookup = Make (struct
  let example =
    with_one_public_input Kimchi_bindings.Protocol.Proof.Fp.example_with_lookup

  let actual_feature_flags =
    { Plonk_types.Features.none_bool with lookup = true; runtime_tables = true }
end)

module Range_check = Make (struct
  let example =
    without_public_input
      Kimchi_bindings.Protocol.Proof.Fp.example_with_range_check

  let actual_feature_flags =
    { Plonk_types.Features.none_bool with
      range_check0 = true
    ; range_check1 = true
    }
end)

module Range_check_64 = Make (struct
  let example =
    without_public_input
      Kimchi_bindings.Protocol.Proof.Fp.example_with_range_check0

  let actual_feature_flags =
    { Plonk_types.Features.none_bool with range_check0 = true }
end)

module Xor = Make (struct
  let example =
    with_two_public_inputs Kimchi_bindings.Protocol.Proof.Fp.example_with_xor

  let actual_feature_flags = { Plonk_types.Features.none_bool with xor = true }
end)

module Rot = Make (struct
  let example =
    with_two_public_inputs Kimchi_bindings.Protocol.Proof.Fp.example_with_rot

  let actual_feature_flags =
    { Plonk_types.Features.none_bool with range_check0 = true; rot = true }
end)

module FFAdd = Make (struct
  let example =
    with_one_public_input Kimchi_bindings.Protocol.Proof.Fp.example_with_ffadd

  let actual_feature_flags =
    { Plonk_types.Features.none_bool with
      range_check0 = true
    ; range_check1 = true
    ; foreign_field_add = true
    }
end)

let tests =
  [ ("Gate:Lookup", Lookup.tests)
  ; ("Gate:Foreign field addition", FFAdd.tests)
  ; ("Gate:Rot", Rot.tests)
  ; ("Gate:Xor", Xor.tests)
  ; ("Gate:Range check", Range_check.tests)
  ; ("Gate:Range_check 64 bits", Range_check_64.tests)
  ]
