module SC = Scalar_challenge
module P = Proof
open Pickles_types
open Hlist
open Common
open Import
open Types
open Backend

(* This contains the "wrap" prover *)

let challenge_polynomial =
  Wrap_verifier.challenge_polynomial (module Backend.Tick.Field)

module Type1 =
  Plonk_checks.Make
    (Shifted_value.Type1)
    (struct
      let constant_term = Plonk_checks.Scalars.Tick.constant_term

      let index_terms = Plonk_checks.Scalars.Tick.index_terms
    end)

let _vector_of_list (type a t)
    (module V : Snarky_intf.Vector.S with type elt = a and type t = t)
    (xs : a list) : t =
  let r = V.create () in
  List.iter xs ~f:(V.emplace_back r) ;
  r

let tick_rounds = Nat.to_int Tick.Rounds.n

let combined_inner_product (type actual_proofs_verified) ~env ~domain ~ft_eval1
    ~actual_proofs_verified:
      (module AB : Nat.Add.Intf with type n = actual_proofs_verified)
    (e : _ Plonk_types.All_evals.With_public_input.t)
    ~(old_bulletproof_challenges : (_, actual_proofs_verified) Vector.t) ~r
    ~plonk ~xi ~zeta ~zetaw =
  let combined_evals =
    Plonk_checks.evals_of_split_evals ~zeta ~zetaw
      (module Tick.Field)
      ~rounds:tick_rounds e.evals
  in
  let ft_eval0 : Tick.Field.t =
    Type1.ft_eval0
      (module Tick.Field)
      plonk ~env ~domain
      (Plonk_types.Evals.to_in_circuit combined_evals)
      (fst e.public_input)
  in
  let T = AB.eq in
  let challenge_polys =
    Vector.map
      ~f:(fun chals -> unstage (challenge_polynomial (Vector.to_array chals)))
      old_bulletproof_challenges
  in
  let a = Plonk_types.Evals.to_list e.evals in
  let combine ~which_eval ~ft pt =
    let f (x, y) = match which_eval with `Fst -> x | `Snd -> y in
    let a = List.map ~f a in
    let v : Tick.Field.t array list =
      List.append
        (List.map (Vector.to_list challenge_polys) ~f:(fun f -> [| f pt |]))
        ([| f e.public_input |] :: [| ft |] :: a)
    in
    let open Tick.Field in
    Pcs_batch.combine_split_evaluations ~xi ~init:Fn.id
      ~mul_and_add:(fun ~acc ~xi fx -> fx + (xi * acc))
      v
  in
  let open Tick.Field in
  combine ~which_eval:`Fst ~ft:ft_eval0 zeta
  + (r * combine ~which_eval:`Snd ~ft:ft_eval1 zetaw)

module Deferred_values = Types.Wrap.Proof_state.Deferred_values

type scalar_challenge_constant = Challenge.Constant.t Scalar_challenge.t

type deferred_values_and_hints =
  { x_hat_evals : Backend.Tick.Field.t * Backend.Tick.Field.t
  ; sponge_digest_before_evaluations : Tick.Field.t
  ; deferred_values :
      ( ( Challenge.Constant.t
        , scalar_challenge_constant
        , Backend.Tick.Field.t Pickles_types.Shifted_value.Type1.t
        , (Tick.Field.t Shifted_value.Type1.t, bool) Opt.t
        , ( scalar_challenge_constant Deferred_values.Plonk.In_circuit.Lookup.t
          , bool )
          Opt.t
        , bool )
        Deferred_values.Plonk.In_circuit.t
      , scalar_challenge_constant
      , Tick.Field.t Shifted_value.Type1.t
      , Challenge.Constant.t Scalar_challenge.t Bulletproof_challenge.t
        Step_bp_vec.t
      , Branch_data.t )
      Deferred_values.t
  }

let deferred_values (type n) ~(sgs : (Backend.Tick.Curve.Affine.t, n) Vector.t)
    ~feature_flags ~actual_feature_flags
    ~(prev_challenges : ((Backend.Tick.Field.t, _) Vector.t, n) Vector.t)
    ~(step_vk : Kimchi_bindings.Protocol.VerifierIndex.Fp.t)
    ~(public_input : Backend.Tick.Field.t list) ~(proof : Backend.Tick.Proof.t)
    ~(actual_proofs_verified : n Nat.t) : deferred_values_and_hints =
  let module O = Tick.Oracles in
  let o =
    O.create step_vk
      Vector.(
        map2 sgs prev_challenges ~f:(fun commitment cs ->
            { Tick.Proof.Challenge_polynomial.commitment
            ; challenges = Vector.to_array cs
            } )
        |> to_list)
      public_input proof
  in
  let x_hat = O.p_eval o in
  let scalar_chal f =
    Scalar_challenge.map ~f:Challenge.Constant.of_tick_field (f o)
  in
  let plonk0 =
    { Types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.alpha =
        scalar_chal O.alpha
    ; beta = O.beta o
    ; gamma = O.gamma o
    ; zeta = scalar_chal O.zeta
    ; joint_combiner =
        (* TODO: Needs to be changed when lookups are fully implemented *)
        Option.map (O.joint_combiner_chal o)
          ~f:(Scalar_challenge.map ~f:Challenge.Constant.of_tick_field)
    ; feature_flags = actual_feature_flags
    }
  in
  let r = scalar_chal O.u in
  let xi = scalar_chal O.v in
  let module As_field = struct
    let to_field =
      SC.to_field_constant
        (module Tick.Field)
        ~endo:Endo.Wrap_inner_curve.scalar

    let r = to_field r

    let xi = to_field xi

    let zeta = to_field plonk0.zeta

    let alpha = to_field plonk0.alpha

    let joint_combiner = Option.map ~f:to_field plonk0.joint_combiner
  end in
  let domain = Domain.Pow_2_roots_of_unity step_vk.domain.log_size_of_group in
  let zetaw = Tick.Field.mul As_field.zeta step_vk.domain.group_gen in
  let tick_plonk_minimal =
    { plonk0 with
      zeta = As_field.zeta
    ; alpha = As_field.alpha
    ; joint_combiner = As_field.joint_combiner
    }
  in
  let tick_combined_evals =
    Plonk_checks.evals_of_split_evals
      (module Tick.Field)
      proof.openings.evals ~rounds:(Nat.to_int Tick.Rounds.n)
      ~zeta:As_field.zeta ~zetaw
    |> Plonk_types.Evals.to_in_circuit
  in
  let tick_domain =
    Plonk_checks.domain
      (module Tick.Field)
      domain ~shifts:Common.tick_shifts
      ~domain_generator:Backend.Tick.Field.domain_generator
  in
  let tick_env =
    let module Env_bool = struct
      type t = bool

      let true_ = true

      let false_ = false

      let ( &&& ) = ( && )

      let ( ||| ) = ( || )

      let any = List.exists ~f:Fn.id
    end in
    let module Env_field = struct
      include Tick.Field

      type bool = Env_bool.t

      let if_ (b : bool) ~then_ ~else_ = if b then then_ () else else_ ()
    end in
    Plonk_checks.scalars_env
      (module Env_bool)
      (module Env_field)
      ~endo:Endo.Step_inner_curve.base ~mds:Tick_field_sponge.params.mds
      ~srs_length_log2:Common.Max_degree.step_log2
      ~field_of_hex:(fun s ->
        Kimchi_pasta.Pasta.Bigint256.of_hex_string s
        |> Kimchi_pasta.Pasta.Fp.of_bigint )
      ~domain:tick_domain tick_plonk_minimal tick_combined_evals
  in
  let plonk =
    let module Field = struct
      include Tick.Field
    end in
    Type1.derive_plonk
      (module Field)
      ~feature_flags ~shift:Shifts.tick1 ~env:tick_env tick_plonk_minimal
      tick_combined_evals
  and new_bulletproof_challenges, b =
    let prechals =
      Array.map (O.opening_prechallenges o) ~f:(fun x ->
          Scalar_challenge.map ~f:Challenge.Constant.of_tick_field x )
    in
    let chals = Array.map prechals ~f:(fun x -> Ipa.Step.compute_challenge x) in
    let challenge_poly = unstage (challenge_polynomial chals) in
    let open As_field in
    let b =
      let open Tick.Field in
      challenge_poly zeta + (r * challenge_poly zetaw)
    in
    let prechals = Array.map prechals ~f:Bulletproof_challenge.unpack in
    (prechals, b)
  in
  let shift_value =
    Shifted_value.Type1.of_field (module Tick.Field) ~shift:Shifts.tick1
  and chal = Challenge.Constant.of_tick_field in
  { deferred_values =
      { Types.Wrap.Proof_state.Deferred_values.xi
      ; b = shift_value b
      ; bulletproof_challenges =
          Vector.of_array_and_length_exn new_bulletproof_challenges
            Tick.Rounds.n
      ; combined_inner_product =
          shift_value
            As_field.(
              combined_inner_product (* Note: We do not pad here. *)
                ~actual_proofs_verified:(Nat.Add.create actual_proofs_verified)
                { evals = proof.openings.evals; public_input = x_hat }
                ~r ~xi ~zeta ~zetaw ~old_bulletproof_challenges:prev_challenges
                ~env:tick_env ~domain:tick_domain
                ~ft_eval1:proof.openings.ft_eval1 ~plonk:tick_plonk_minimal)
      ; branch_data =
          { proofs_verified =
              ( match actual_proofs_verified with
              | Z ->
                  Branch_data.Proofs_verified.N0
              | S Z ->
                  N1
              | S (S Z) ->
                  N2
              | S _ ->
                  assert false )
          ; domain_log2 =
              Branch_data.Domain_log2.of_int_exn
                step_vk.domain.log_size_of_group
          }
      ; plonk =
          { plonk with
            zeta = plonk0.zeta
          ; alpha = plonk0.alpha
          ; beta = chal plonk0.beta
          ; gamma = chal plonk0.gamma
          ; lookup =
              Opt.map plonk.lookup ~f:(fun _ ->
                  { Composition_types.Wrap.Proof_state.Deferred_values.Plonk
                    .In_circuit
                    .Lookup
                    .joint_combiner = Option.value_exn plonk0.joint_combiner
                  } )
          }
      }
  ; x_hat_evals = x_hat
  ; sponge_digest_before_evaluations = O.digest_before_evaluations o
  }

(* Testing
   -------

   Invocation:
   dune exec src/lib/pickles/.pickles.inline-tests/inline_test_runner_pickles.exe \
   --profile=dev --display short -- inline-test-runner pickles -only-test wrap.ml
*)
let%test_module "gate finalization" =
  ( module struct
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
         @param true_opt  Plonk_types.Opt type to use for true/enabled features
         @param false_opt Plonk_types.Opt type to use for false/disabled features
         @return Corresponding feature flags composed of Yes/No/Maybe values *)
      let compute_feature_flags
          (actual_feature_flags : Plonk_types.Features.flags)
          (true_opt : Plonk_types.Opt.Flag.t)
          (false_opt : Plonk_types.Opt.Flag.t) : Plonk_types.Features.options =
        Plonk_types.Features.map actual_feature_flags ~f:(function
          | true ->
              true_opt
          | false ->
              false_opt )
      in

      (* Generate the 3 configurations of the actual feature flags using
         helper *)
      let open Plonk_types.Opt.Flag in
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
    let run_recursive_proof_test
        (actual_feature_flags : Plonk_types.Features.flags)
        (feature_flags : Plonk_types.Features.options)
        (public_input : Pasta_bindings.Fp.t list)
        (vk : Kimchi_bindings.Protocol.VerifierIndex.Fp.t)
        (proof : Backend.Tick.Proof.t) : Impls.Step.Boolean.value =
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
      let { deferred_values; x_hat_evals; sponge_digest_before_evaluations } =
        deferred_values ~feature_flags ~actual_feature_flags ~sgs:[]
          ~prev_challenges:[] ~step_vk:vk ~public_input ~proof
          ~actual_proofs_verified:Nat.N0.n
      in

      (* Define Typ.t for Deferred_values.t -- A Type.t defines how to convert a value of some type
                                              in OCaml into a var in circuit/Snarky.

         This complex function is called with two sets of inputs: once for the step circuit and
         once for the wrap circuit.  It was decided not to use a functor for this. *)
      let deferred_values_typ =
        let open Impls.Step in
        let open Step_main_inputs in
        let open Step_verifier in
        Wrap.Proof_state.Deferred_values.In_circuit.typ
          (module Impls.Step)
          ~feature_flags ~challenge:Challenge.typ
          ~scalar_challenge:Challenge.typ
          ~dummy_scalar:(Shifted_value.Type1.Shifted_value Field.Constant.zero)
          ~dummy_scalar_challenge:
            (Kimchi_backend_common.Scalar_challenge.create
               Limb_vector.Challenge.Constant.zero )
          (Shifted_value.Type1.typ Field.typ)
          (Branch_data.typ
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
                lookup = Opt.to_option_unsafe deferred_values.plonk.lookup
              ; optional_column_scalars =
                  Composition_types.Wrap.Proof_state.Deferred_values.Plonk
                  .In_circuit
                  .Optional_column_scalars
                  .map ~f:Opt.to_option
                    deferred_values.plonk.optional_column_scalars
              }
          }
      (* Prepare all of the evaluations (i.e. all of the columns in the proof that we open)
         for use in the circuit *)
      and evals =
        constant
          (Plonk_types.All_evals.typ (module Impls.Step) feature_flags)
          { evals = { public_input = x_hat_evals; evals = proof.openings.evals }
          ; ft_eval1 = proof.openings.ft_eval1
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
              ~feature_flags
              ~step_domains:
                (`Known
                  [ { h = Pow_2_roots_of_unity vk.domain.log_size_of_group } ]
                  )
              ~sponge ~prev_challenges:[] deferred_values evals
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
        run_recursive_proof_test S.actual_feature_flags feature_flags
          public_input vk proof.proof

      let%test "true -> yes" = runtest test_feature_flags_configs.true_is_yes

      let%test "true -> maybe" =
        runtest test_feature_flags_configs.true_is_maybe

      let%test "all maybes" = runtest test_feature_flags_configs.all_maybes
    end

    (* Small combinators to lift gate example signatures to the expected
       signatures for the tests. This amounts to generating the list of public
       inputs from either no public inputs, a single one or a pair of inputs
       returned by the gate example. *)

    let no_public_input gate_example srs =
      let index, proof = gate_example srs in
      (index, [], proof)

    let public_input_1 gate_example srs =
      let index, public_input, proof = gate_example srs in
      (index, [ public_input ], proof)

    let public_input_2 gate_example srs =
      let index, (public_input1, public_input2), proof = gate_example srs in
      (index, [ public_input1; public_input2 ], proof)

    let%test_module "lookup" =
      ( module Make (struct
        let example =
          public_input_1 (fun srs ->
              Kimchi_bindings.Protocol.Proof.Fp.example_with_lookup srs true )

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            lookup = true
          ; runtime_tables = true
          }
      end) )

    let%test_module "foreign field multiplication" =
      ( module Make (struct
        let example =
          no_public_input
            Kimchi_bindings.Protocol.Proof.Fp.example_with_foreign_field_mul

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            range_check0 = true
          ; range_check1 = true
          ; foreign_field_add = true
          ; foreign_field_mul = true
          ; lookup = true
          }
      end) )

    let%test_module "range check" =
      ( module Make (struct
        let example =
          no_public_input
            Kimchi_bindings.Protocol.Proof.Fp.example_with_range_check

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            range_check0 = true
          ; range_check1 = true
          ; lookup = true
          }
      end) )

    let%test_module "range check 64 bits" =
      ( module Make (struct
        let example =
          no_public_input
            Kimchi_bindings.Protocol.Proof.Fp.example_with_range_check0

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            range_check0 = true
          ; lookup = true
          }
      end) )

    let%test_module "xor" =
      ( module Make (struct
        let example =
          public_input_2 Kimchi_bindings.Protocol.Proof.Fp.example_with_xor

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with xor = true; lookup = true }
      end) )

    let%test_module "rot" =
      ( module Make (struct
        let example =
          public_input_2 Kimchi_bindings.Protocol.Proof.Fp.example_with_rot

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            range_check0 = true
          ; rot = true
          ; lookup = true
          }
      end) )

    let%test_module "foreign field addition" =
      ( module Make (struct
        let example =
          public_input_1 Kimchi_bindings.Protocol.Proof.Fp.example_with_ffadd

        let actual_feature_flags =
          { Plonk_types.Features.none_bool with
            range_check0 = true
          ; range_check1 = true
          ; foreign_field_add = true
          ; lookup = true
          }
      end) )
  end )

module Step_acc = Tock.Inner_curve.Affine

(* The prover for wrapping a proof *)
let wrap
    (type actual_proofs_verified max_proofs_verified
    max_local_max_proofs_verifieds )
    ~(max_proofs_verified : max_proofs_verified Nat.t)
    (module Max_local_max_proof_verifieds : Hlist.Maxes.S
      with type ns = max_local_max_proofs_verifieds
       and type length = max_proofs_verified )
    (( module
      Req ) :
      (max_proofs_verified, max_local_max_proofs_verifieds) Requests.Wrap.t )
    ~dlog_plonk_index wrap_main ~(typ : _ Impls.Step.Typ.t) ~step_vk
    ~actual_wrap_domains ~step_plonk_indices:_ ~feature_flags
    ~actual_feature_flags ?tweak_statement pk
    ({ statement = prev_statement; prev_evals; proof; index = which_index } :
      ( _
      , _
      , (_, actual_proofs_verified) Vector.t
      , (_, actual_proofs_verified) Vector.t
      , max_local_max_proofs_verifieds
        H1.T(P.Base.Messages_for_next_proof_over_same_field.Wrap).t
      , ( (Tock.Field.t, Tock.Field.t array) Plonk_types.All_evals.t
        , max_proofs_verified )
        Vector.t )
      P.Base.Step.t ) =
  let logger = Internal_tracing_context_logger.get () in
  [%log internal] "Pickles_wrap_proof" ;
  let messages_for_next_wrap_proof =
    let module M =
      H1.Map
        (P.Base.Messages_for_next_proof_over_same_field.Wrap)
        (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
        (struct
          let f = P.Base.Messages_for_next_proof_over_same_field.Wrap.prepare
        end)
    in
    M.f prev_statement.messages_for_next_wrap_proof
  in
  let prev_statement_with_hashes : _ Types.Step.Statement.t =
    { proof_state =
        { prev_statement.proof_state with
          messages_for_next_step_proof =
            (let to_field_elements =
               let (Typ typ) = typ in
               fun x -> fst (typ.value_to_fields x)
             in
             (* TODO: Careful here... the length of
                old_buletproof_challenges inside the messages_for_next_step_proof
                might not be correct *)
             Common.hash_messages_for_next_step_proof
               ~app_state:to_field_elements
               (P.Base.Messages_for_next_proof_over_same_field.Step.prepare
                  ~dlog_plonk_index
                  prev_statement.proof_state.messages_for_next_step_proof ) )
        }
    ; messages_for_next_wrap_proof =
        (let module M =
           H1.Map
             (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
             (E01 (Digest.Constant))
             (struct
               let f (type n)
                   (m :
                     n
                     P.Base.Messages_for_next_proof_over_same_field.Wrap
                     .Prepared
                     .t ) =
                 Wrap_hack.hash_messages_for_next_wrap_proof
                   (Vector.length m.old_bulletproof_challenges)
                   m
             end)
         in
        let module V = H1.To_vector (Digest.Constant) in
        V.f Max_local_max_proof_verifieds.length
          (M.f messages_for_next_wrap_proof) )
    }
  in
  let handler (Snarky_backendless.Request.With { request; respond }) =
    let open Req in
    let k x = respond (Provide x) in
    match request with
    | Evals ->
        k prev_evals
    | Step_accs ->
        let module M =
          H1.Map
            (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
            (E01 (Step_acc))
            (struct
              let f :
                  type a.
                     a
                     P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared
                     .t
                  -> Step_acc.t =
               fun t -> t.challenge_polynomial_commitment
            end)
        in
        let module V = H1.To_vector (Step_acc) in
        k
          (V.f Max_local_max_proof_verifieds.length
             (M.f messages_for_next_wrap_proof) )
    | Old_bulletproof_challenges ->
        let module M =
          H1.Map
            (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
            (Challenges_vector.Constant)
            (struct
              let f
                  (t :
                    _
                    P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared
                    .t ) =
                t.old_bulletproof_challenges
            end)
        in
        k (M.f messages_for_next_wrap_proof)
    | Messages ->
        k proof.messages
    | Openings_proof ->
        k proof.openings.proof
    | Proof_state ->
        k prev_statement_with_hashes.proof_state
    | Which_branch ->
        k which_index
    | Wrap_domain_indices ->
        let all_possible_domains = Wrap_verifier.all_possible_domains () in
        let wrap_domain_indices =
          Vector.map actual_wrap_domains ~f:(fun domain_size ->
              let domain_index =
                Vector.foldi ~init:0 all_possible_domains
                  ~f:(fun j acc (Pow_2_roots_of_unity domain) ->
                    if Int.equal domain domain_size then j else acc )
              in
              Tock.Field.of_int domain_index )
        in
        k
          (Vector.extend_front_exn wrap_domain_indices max_proofs_verified
             Tock.Field.one )
    | _ ->
        Snarky_backendless.Request.unhandled
  in

  let public_input =
    tick_public_input_of_statement ~max_proofs_verified
      prev_statement_with_hashes ~feature_flags
  in
  let prev_challenges =
    Vector.map ~f:Ipa.Step.compute_challenges
      prev_statement.proof_state.messages_for_next_step_proof
        .old_bulletproof_challenges
  in
  let actual_proofs_verified = Vector.length prev_challenges in
  let lte =
    Nat.lte_exn actual_proofs_verified
      (Length.to_nat Max_local_max_proof_verifieds.length)
  in
  let sgs =
    let module M =
      H1.Map
        (P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared)
        (E01 (Tick.Curve.Affine))
        (struct
          let f :
              type n.
                 n P.Base.Messages_for_next_proof_over_same_field.Wrap.Prepared.t
              -> _ =
           fun t -> t.challenge_polynomial_commitment
        end)
    in
    let module V = H1.To_vector (Tick.Curve.Affine) in
    Vector.trim_front
      (V.f Max_local_max_proof_verifieds.length
         (M.f messages_for_next_wrap_proof) )
      lte
  in
  [%log internal] "Wrap_compute_deferred_values" ;
  let { deferred_values; x_hat_evals; sponge_digest_before_evaluations } =
    deferred_values ~sgs ~prev_challenges ~step_vk ~public_input ~proof
      ~actual_proofs_verified ~feature_flags ~actual_feature_flags
  in
  [%log internal] "Wrap_compute_deferred_values_done" ;
  let next_statement : _ Types.Wrap.Statement.In_circuit.t =
    let messages_for_next_wrap_proof :
        _ P.Base.Messages_for_next_proof_over_same_field.Wrap.t =
      { challenge_polynomial_commitment =
          proof.openings.proof.challenge_polynomial_commitment
      ; old_bulletproof_challenges =
          Vector.map prev_statement.proof_state.unfinalized_proofs ~f:(fun t ->
              t.deferred_values.bulletproof_challenges )
      }
    in
    { proof_state =
        { deferred_values
        ; sponge_digest_before_evaluations =
            Digest.Constant.of_tick_field sponge_digest_before_evaluations
        ; messages_for_next_wrap_proof
        }
    ; messages_for_next_step_proof =
        prev_statement.proof_state.messages_for_next_step_proof
    }
  in
  let next_statement =
    match tweak_statement with
    | None ->
        next_statement
    | Some f ->
        (* For adversarial tests, we want to simulate an adversary creating a
           proof that doesn't match the pickles protocol.
           In order to do this, we pass a function [tweak_statement] that takes
           the valid statement that we computed above and 'tweaks' it so that
           the statement is no longer valid. This modified statement is then
           propagated as part of any later recursion.
        *)
        f next_statement
  in
  let messages_for_next_wrap_proof_prepared =
    P.Base.Messages_for_next_proof_over_same_field.Wrap.prepare
      next_statement.proof_state.messages_for_next_wrap_proof
  in
  let next_accumulator =
    Vector.map2
      (Vector.extend_front_exn
         prev_statement.proof_state.messages_for_next_step_proof
           .challenge_polynomial_commitments max_proofs_verified
         (Lazy.force Dummy.Ipa.Wrap.sg) )
      messages_for_next_wrap_proof_prepared.old_bulletproof_challenges
      ~f:(fun sg chals ->
        { Tock.Proof.Challenge_polynomial.commitment = sg
        ; challenges = Vector.to_array chals
        } )
    |> Wrap_hack.pad_accumulator
  in
  let%map.Promise next_proof =
    let (T (input, conv, _conv_inv)) = Impls.Wrap.input () in
    Common.time "wrap proof" (fun () ->
        [%log internal] "Wrap_generate_witness_conv" ;
        Impls.Wrap.generate_witness_conv
          ~f:(fun { Impls.Wrap.Proof_inputs.auxiliary_inputs; public_inputs } () ->
            [%log internal] "Backend_tock_proof_create_async" ;
            let%map.Promise proof =
              Backend.Tock.Proof.create_async ~primary:public_inputs
                ~auxiliary:auxiliary_inputs pk ~message:next_accumulator
            in
            [%log internal] "Backend_tock_proof_create_async_done" ;
            proof )
          ~input_typ:input
          ~return_typ:(Snarky_backendless.Typ.unit ())
          (fun x () : unit ->
            Impls.Wrap.handle (fun () : unit -> wrap_main (conv x)) handler )
          { messages_for_next_step_proof =
              prev_statement_with_hashes.proof_state
                .messages_for_next_step_proof
          ; proof_state =
              { next_statement.proof_state with
                messages_for_next_wrap_proof =
                  Wrap_hack.hash_messages_for_next_wrap_proof
                    max_proofs_verified messages_for_next_wrap_proof_prepared
              ; deferred_values =
                  { next_statement.proof_state.deferred_values with
                    plonk =
                      { next_statement.proof_state.deferred_values.plonk with
                        lookup =
                          (* TODO: This assumes wrap circuits do not use lookup *)
                          None
                      ; optional_column_scalars =
                          (* TODO: This assumes that wrap circuits do not use
                             optional gates.
                          *)
                          { range_check0 = None
                          ; range_check1 = None
                          ; foreign_field_add = None
                          ; foreign_field_mul = None
                          ; xor = None
                          ; rot = None
                          ; lookup_gate = None
                          ; runtime_tables = None
                          }
                      }
                  }
              }
          } )
  in
  [%log internal] "Pickles_wrap_proof_done" ;
  ( { proof = next_proof.proof
    ; statement =
        Types.Wrap.Statement.to_minimal next_statement
          ~to_option:Opt.to_option_unsafe
    ; prev_evals =
        { Plonk_types.All_evals.evals =
            { public_input = x_hat_evals; evals = proof.openings.evals }
        ; ft_eval1 = proof.openings.ft_eval1
        }
    }
    : _ P.Base.Wrap.t )
