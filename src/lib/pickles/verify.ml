module SC = Scalar_challenge
open Pickles_types
open Common
open Import
open Backend

module Instance = struct
  type t =
    | T :
        (module Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
end

(* TODO: Just stick this in plonk_checks.ml *)
module Plonk_checks = struct
  include Plonk_checks
  module Type1 =
    Plonk_checks.Make (Shifted_value.Type1) (Plonk_checks.Scalars.Tick)
end

let verify_heterogenous (ts : Instance.t list) =
  let module Tick_field = Backend.Tick.Field in
  let logger = Internal_tracing_context_logger.get () in
  [%log internal] "Verify_heterogenous"
    ~metadata:[ ("count", `Int (List.length ts)) ] ;
  let tick_field : _ Plonk_checks.field = (module Tick_field) in
  let check, result =
    let r = ref [] in
    let result () =
      match !r with
      | [] ->
          Ok ()
      | _ ->
          Error
            ( Error.tag ~tag:"Pickles.verify"
            @@ Error.of_list
            @@ List.map !r ~f:(fun lab -> Error.of_string (Lazy.force lab)) )
    in
    ((fun (lab, b) -> if not b then r := lab :: !r), result)
  in
  [%log internal] "Compute_plonks_and_chals" ;
  let in_circuit_plonks, _computed_bp_chals =
    List.map ts
      ~f:(fun
           (T
             ( _max_proofs_verified
             , _statement
             , key
             , app_state
             , T
                 { statement
                   (* TODO
                      ; prev_x_hat = (x_hat1, _) as prev_x_hat
                   *)
                 ; prev_evals = evals
                 ; proof = _
                 } ) )
         ->
        Timer.start __LOC__ ;
        let statement =
          { statement with
            messages_for_next_step_proof =
              { statement.messages_for_next_step_proof with app_state }
          }
        in
        let open Types.Wrap.Proof_state in
        let sc =
          SC.to_field_constant tick_field ~endo:Endo.Wrap_inner_curve.scalar
        in
        Timer.clock __LOC__ ;
        let { Deferred_values.xi
            ; plonk = plonk0
            ; combined_inner_product
            ; branch_data
            ; bulletproof_challenges
            ; b
            } =
          Deferred_values.map_challenges ~f:Challenge.Constant.to_tick_field
            ~scalar:sc statement.proof_state.deferred_values
        in
        let zeta = sc plonk0.zeta in
        let alpha = sc plonk0.alpha in
        let step_domain = Branch_data.domain branch_data in
        check
          ( lazy "domain size is small enough"
          , Domain.log2_size step_domain <= Nat.to_int Backend.Tick.Rounds.n ) ;
        let w =
          Tick.Field.domain_generator ~log2_size:(Domain.log2_size step_domain)
        in
        let zetaw = Tick.Field.mul zeta w in
        let tick_plonk_minimal :
            _ Composition_types.Wrap.Proof_state.Deferred_values.Plonk.Minimal.t
            =
          let chal = Challenge.Constant.to_tick_field in
          { zeta
          ; alpha
          ; beta = chal plonk0.beta
          ; gamma = chal plonk0.gamma
          ; joint_combiner = Option.map ~f:sc plonk0.joint_combiner
          ; feature_flags = plonk0.feature_flags
          }
        in
        let tick_combined_evals =
          Plonk_checks.evals_of_split_evals
            (module Tick.Field)
            evals.evals.evals ~rounds:(Nat.to_int Tick.Rounds.n) ~zeta ~zetaw
          |> Plonk_types.Evals.to_in_circuit
        in
        let tick_domain =
          Plonk_checks.domain
            (module Tick.Field)
            step_domain ~shifts:Common.tick_shifts
            ~domain_generator:Backend.Tick.Field.domain_generator
        in
        let feature_flags =
          Plonk_types.Features.map
            ~f:(function
              | false ->
                  Plonk_types.Opt.Flag.No
              | true ->
                  Plonk_types.Opt.Flag.Yes )
            plonk0.feature_flags
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
          let p =
            let module Field = struct
              include Tick.Field
            end in
            Plonk_checks.Type1.derive_plonk
              (module Field)
              ~feature_flags ~shift:Shifts.tick1 ~env:tick_env
              tick_plonk_minimal tick_combined_evals
          in
          { p with
            zeta = plonk0.zeta
          ; alpha = plonk0.alpha
          ; beta = plonk0.beta
          ; gamma = plonk0.gamma
          ; lookup =
              Option.map (Plonk_types.Opt.to_option_unsafe p.lookup)
                ~f:(fun _l ->
                  { Types.Wrap.Proof_state.Deferred_values.Plonk.In_circuit
                    .Lookup
                    .joint_combiner = Option.value_exn plonk0.joint_combiner
                  } )
          ; optional_column_scalars =
              Composition_types.Wrap.Proof_state.Deferred_values.Plonk
              .In_circuit
              .Optional_column_scalars
              .map ~f:Plonk_types.Opt.to_option p.optional_column_scalars
          }
        in
        Timer.clock __LOC__ ;
        let absorb, squeeze =
          let open Tick_field_sponge.Bits in
          let sponge =
            let s = create Tick_field_sponge.params in
            absorb s
              (Digest.Constant.to_tick_field
                 statement.proof_state.sponge_digest_before_evaluations ) ;
            s
          in
          let squeeze () =
            let underlying =
              Challenge.Constant.of_bits
                (squeeze sponge ~length:Challenge.Constant.length)
            in
            sc (Scalar_challenge.create underlying)
          in
          (absorb sponge, squeeze)
        in
        let old_bulletproof_challenges =
          Vector.map ~f:Ipa.Step.compute_challenges
            statement.messages_for_next_step_proof.old_bulletproof_challenges
        in
        (let challenges_digest =
           let open Tick_field_sponge.Field in
           let sponge = create Tick_field_sponge.params in
           Vector.iter old_bulletproof_challenges
             ~f:(Vector.iter ~f:(absorb sponge)) ;
           squeeze sponge
         in
         absorb challenges_digest ;
         absorb evals.ft_eval1 ;
         let xs = Plonk_types.Evals.to_absorption_sequence evals.evals.evals in
         let x1, x2 = evals.evals.public_input in
         absorb x1 ;
         absorb x2 ;
         List.iter xs ~f:(fun (x1, x2) ->
             Array.iter ~f:absorb x1 ; Array.iter ~f:absorb x2 ) ) ;
        let xi_actual = squeeze () in
        let r_actual = squeeze () in
        Timer.clock __LOC__ ;
        (* TODO: The deferred values "bulletproof_challenges" should get routed
           into a "batch dlog Tick acc verifier" *)
        let actual_proofs_verified = Vector.length old_bulletproof_challenges in
        Timer.clock __LOC__ ;
        let combined_inner_product_actual =
          Wrap.combined_inner_product ~env:tick_env ~plonk:tick_plonk_minimal
            ~domain:tick_domain ~ft_eval1:evals.ft_eval1
            ~actual_proofs_verified:(Nat.Add.create actual_proofs_verified)
            evals.evals ~old_bulletproof_challenges ~r:r_actual ~xi ~zeta ~zetaw
        in
        let check_eq lab x y =
          check
            ( lazy
                (sprintf
                   !"%s: %{sexp:Tick_field.t} != %{sexp:Tick_field.t}"
                   lab x y )
            , Tick_field.equal x y )
        in
        Timer.clock __LOC__ ;
        let bulletproof_challenges =
          Ipa.Step.compute_challenges bulletproof_challenges
        in
        Timer.clock __LOC__ ;
        let shifted_value =
          Shifted_value.Type1.to_field (module Tick.Field) ~shift:Shifts.tick1
        in
        let b_actual =
          let challenge_poly =
            unstage
              (Wrap.challenge_polynomial
                 (Vector.to_array bulletproof_challenges) )
          in
          Tick.Field.(challenge_poly zeta + (r_actual * challenge_poly zetaw))
        in
        let () =
          let [ Pow_2_roots_of_unity greatest_wrap_domain
              ; _
              ; Pow_2_roots_of_unity least_wrap_domain
              ] =
            Wrap_verifier.all_possible_domains ()
          in
          let actual_wrap_domain = key.index.domain.log_size_of_group in
          check
            ( lazy
                (sprintf !"wrap_domain: %i > %i" actual_wrap_domain
                   least_wrap_domain )
            , Int.( <= ) actual_wrap_domain least_wrap_domain ) ;
          check
            ( lazy
                (sprintf !"wrap_domain: %i < %i" actual_wrap_domain
                   greatest_wrap_domain )
            , Int.( >= ) actual_wrap_domain greatest_wrap_domain )
        in
        List.iter
          ~f:(fun (s, x, y) -> check_eq s x y)
          (* Both these values can actually be omitted from the proof on the wire since we recompute them
             anyway. *)
          [ ("xi", xi, xi_actual)
          ; ( "combined_inner_product"
            , shifted_value combined_inner_product
            , combined_inner_product_actual )
          ; ("b", shifted_value b, b_actual)
          ] ;
        (plonk, bulletproof_challenges) )
    |> List.unzip
  in
  [%log internal] "Compute_plonks_and_chals_done" ;
  let open Backend.Tock.Proof in
  let open Promise.Let_syntax in
  [%log internal] "Accumulator_check" ;
  let%bind accumulator_check =
    Ipa.Step.accumulator_check
      (List.map ts ~f:(fun (T (_, _, _, _, T t)) ->
           ( t.statement.proof_state.messages_for_next_wrap_proof
               .challenge_polynomial_commitment
           , Ipa.Step.compute_challenges
               t.statement.proof_state.deferred_values.bulletproof_challenges ) )
      )
  in
  [%log internal] "Accumulator_check_done" ;
  Common.time "batch_step_dlog_check" (fun () ->
      check (lazy "batch_step_dlog_check", accumulator_check) ) ;
  [%log internal] "Compute_batch_verify_inputs" ;
  let batch_verify_inputs =
    List.map2_exn ts in_circuit_plonks
      ~f:(fun
           (T
             ( (module Max_proofs_verified)
             , (module A_value)
             , key
             , app_state
             , T t ) )
           plonk
         ->
        let prepared_statement : _ Types.Wrap.Statement.In_circuit.t =
          { messages_for_next_step_proof =
              Common.hash_messages_for_next_step_proof
                ~app_state:A_value.to_field_elements
                (Reduced_messages_for_next_proof_over_same_field.Step.prepare
                   ~dlog_plonk_index:key.commitments
                   { t.statement.messages_for_next_step_proof with app_state } )
          ; proof_state =
              { t.statement.proof_state with
                deferred_values =
                  { t.statement.proof_state.deferred_values with plonk }
              ; messages_for_next_wrap_proof =
                  Wrap_hack.hash_messages_for_next_wrap_proof
                    Max_proofs_verified.n
                    (Reduced_messages_for_next_proof_over_same_field.Wrap
                     .prepare
                       t.statement.proof_state.messages_for_next_wrap_proof )
              }
          }
        in
        let input =
          tock_unpadded_public_input_of_statement prepared_statement
        in
        let message =
          Wrap_hack.pad_accumulator
            (Vector.map2
               ~f:(fun g cs ->
                 { Challenge_polynomial.challenges =
                     Vector.to_array (Ipa.Wrap.compute_challenges cs)
                 ; commitment = g
                 } )
               (Vector.extend_front_exn
                  t.statement.messages_for_next_step_proof
                    .challenge_polynomial_commitments Max_proofs_verified.n
                  (Lazy.force Dummy.Ipa.Wrap.sg) )
               t.statement.proof_state.messages_for_next_wrap_proof
                 .old_bulletproof_challenges )
        in
        ( key.index
        , { proof = t.proof; public_evals = None }
        , input
        , Some message ) )
  in
  [%log internal] "Compute_batch_verify_inputs_done" ;
  [%log internal] "Dlog_check_batch_verify" ;
  let%map dlog_check = batch_verify batch_verify_inputs in
  [%log internal] "Dlog_check_batch_verify_done" ;
  Common.time "dlog_check" (fun () -> check (lazy "dlog_check", dlog_check)) ;
  result ()

let verify (type a n) (max_proofs_verified : (module Nat.Intf with type n = n))
    (a_value : (module Intf.Statement_value with type t = a))
    (key : Verification_key.t) (ts : (a * (n, n) Proof.t) list) =
  verify_heterogenous
    (List.map ts ~f:(fun (x, p) ->
         Instance.T (max_proofs_verified, a_value, key, x, p) ) )
