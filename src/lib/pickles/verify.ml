module SC = Scalar_challenge
open Pickles_types
open Common
open Import

module Instance = struct
  type chunking_data = { num_chunks : int; domain_size : int; zk_rows : int }

  type t =
    | T :
        (module Nat.Intf with type n = 'n)
        * (module Intf.Statement_value with type t = 'a)
        * chunking_data option
        * Verification_key.t
        * 'a
        * ('n, 'n) Proof.t
        -> t
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
  let _computed_bp_chals, deferred_values =
    List.map ts
      ~f:(fun
           (T
             ( _max_proofs_verified
             , _statement
             , chunking_data
             , key
             , _app_state
             , T
                 { statement =
                     { proof_state
                     ; messages_for_next_step_proof =
                         { old_bulletproof_challenges; _ }
                     }
                 ; prev_evals = evals
                 ; proof = _
                 } ) )
         ->
        Timer.start __LOC__ ;
        let non_chunking, expected_num_chunks =
          let expected_num_chunks =
            Option.value_map ~default:1 chunking_data ~f:(fun x ->
                x.Instance.num_chunks )
          in
          let exception Is_chunked in
          match
            Pickles_types.Plonk_types.Evals.map evals.evals.evals
              ~f:(fun (x, y) ->
                if
                  Array.length x > expected_num_chunks
                  || Array.length y > expected_num_chunks
                then raise Is_chunked )
          with
          | exception Is_chunked ->
              (false, expected_num_chunks)
          | _unit_evals ->
              (* we do not care about _unit_evals, if we reached this point, we
                 know all evals have length 1 for they cannot have length 0 *)
              (true, expected_num_chunks)
        in
        check
          ( lazy (sprintf "only uses %i chunks" expected_num_chunks)
          , non_chunking ) ;
        check
          ( lazy "feature flags are consistent with evaluations"
          , Pickles_types.Plonk_types.Evals.validate_feature_flags
              ~feature_flags:proof_state.deferred_values.plonk.feature_flags
              evals.evals.evals ) ;
        Timer.start __LOC__ ;
        let open Types.Wrap.Proof_state in
        let step_domain =
          Branch_data.domain proof_state.deferred_values.branch_data
        in
        let expected_domain_size =
          match chunking_data with
          | None ->
              Nat.to_int Backend.Tick.Rounds.n
          | Some { domain_size; _ } ->
              domain_size
        in
        check
          ( lazy "domain size is small enough"
          , Domain.log2_size step_domain <= expected_domain_size ) ;
        let sc =
          SC.to_field_constant tick_field ~endo:Endo.Wrap_inner_curve.scalar
        in
        Timer.clock __LOC__ ;
        let { Deferred_values.Minimal.plonk = _
            ; branch_data = _
            ; bulletproof_challenges
            } =
          Deferred_values.Minimal.map_challenges
            ~f:Challenge.Constant.to_tick_field ~scalar:sc
            proof_state.deferred_values
        in
        Timer.clock __LOC__ ;
        let deferred_values =
          let zk_rows =
            Option.value_map ~default:3 chunking_data ~f:(fun x ->
                x.Instance.zk_rows )
          in
          Wrap_deferred_values.expand_deferred ~evals ~zk_rows
            ~old_bulletproof_challenges ~proof_state
        in
        Timer.clock __LOC__ ;
        let deferred_values = { deferred_values with bulletproof_challenges } in
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
        (bulletproof_challenges, deferred_values) )
    |> List.unzip
  in
  [%log internal] "Compute_plonks_and_chals_done" ;
  let open Backend.Tock.Proof in
  let open Promise.Let_syntax in
  [%log internal] "Accumulator_check" ;
  let%bind accumulator_check =
    Ipa.Step.accumulator_check
      (List.map ts ~f:(fun (T (_, _, _, _, _, T t)) ->
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
    List.map2_exn ts deferred_values
      ~f:(fun
           (T
             ( (module Max_proofs_verified)
             , (module A_value)
             , _chunking_data
             , key
             , app_state
             , T t ) )
           deferred_values
         ->
        let prepared_statement : _ Types.Wrap.Statement.In_circuit.t =
          { messages_for_next_step_proof =
              Common.hash_messages_for_next_step_proof
                ~app_state:A_value.to_field_elements
                (Reduced_messages_for_next_proof_over_same_field.Step.prepare
                   ~dlog_plonk_index:
                     (Plonk_verification_key_evals.map
                        ~f:(fun x -> [| x |])
                        key.commitments )
                   { t.statement.messages_for_next_step_proof with app_state } )
          ; proof_state =
              { deferred_values =
                  { plonk = deferred_values.plonk
                  ; combined_inner_product =
                      deferred_values.combined_inner_product
                  ; b = deferred_values.b
                  ; xi = deferred_values.xi
                  ; bulletproof_challenges =
                      deferred_values.bulletproof_challenges
                  ; branch_data = deferred_values.branch_data
                  }
              ; sponge_digest_before_evaluations =
                  t.statement.proof_state.sponge_digest_before_evaluations
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
          tock_unpadded_public_input_of_statement
            ~feature_flags:Plonk_types.Features.Full.maybe prepared_statement
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
        , { proof = Wrap_wire_proof.to_kimchi_proof t.proof
          ; public_evals = None
          }
        , input
        , Some message ) )
  in
  [%log internal] "Compute_batch_verify_inputs_done" ;
  [%log internal] "Dlog_check_batch_verify" ;
  let%map dlog_check = batch_verify batch_verify_inputs in
  [%log internal] "Dlog_check_batch_verify_done" ;
  Common.time "dlog_check" (fun () -> check (lazy "dlog_check", dlog_check)) ;
  result ()

let verify (type a n) ?chunking_data
    (max_proofs_verified : (module Nat.Intf with type n = n))
    (a_value : (module Intf.Statement_value with type t = a))
    (key : Verification_key.t) (ts : (a * (n, n) Proof.t) list) =
  verify_heterogenous
    (List.map ts ~f:(fun (x, p) ->
         Instance.T (max_proofs_verified, a_value, chunking_data, key, x, p) )
    )
