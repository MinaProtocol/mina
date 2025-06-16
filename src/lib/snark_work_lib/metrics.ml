open Core_kernel

type snark_work_generated =
  | Merge_generated of Time.Span.t
  | Base_generated of
      { transaction_type :
          [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
      ; elapsed : Time.Span.t
      ; zkapp_command_count : int
      ; proof_zkapp_command_count : int
      }
  | Sub_zkapp_command of { kind : [ `Merge | `Segment ]; elapsed : Time.Span.t }

let collect_single ~(single_spec : Single_spec.Stable.Latest.t)
    ~data:
      ({ data = elapsed; _ } :
        (Core.Time.Stable.Span.V1.t, _) Proof_carrying_data.t ) =
  match single_spec with
  | Single_spec.Poly.Merge (_, _, _) ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      Merge_generated elapsed
  | Single_spec.Poly.Transition
      (_, ({ transaction; _ } : Transaction_witness.Stable.Latest.t)) ->
      Perf_histograms.add_span ~name:"snark_worker_transition_time" elapsed ;
      let transaction_type, zkapp_command_count, proof_zkapp_command_count =
        match transaction with
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Zkapp_command zkapp_command) ->
            (* WARN: now this is dead code, if we're using new protocol between
               snark coordinator and workers *)
            let parties_count = List.length zkapp_command.account_updates in
            let proof_parties_count_init =
              match
                (Mina_base.Account_update.of_fee_payer
                   zkapp_command.Mina_base.Zkapp_command.Poly.fee_payer )
                  .authorization
              with
              | Proof _ ->
                  1
              | _ ->
                  0
            in
            let proof_parties_count =
              Mina_base.Zkapp_command.Call_forest.fold
                zkapp_command.account_updates ~init:proof_parties_count_init
                ~f:(fun cnt account_update ->
                  if
                    Mina_base.Control.(
                      Tag.equal Proof
                        (tag
                           account_update
                             .Mina_base.Account_update.Poly.authorization ))
                  then cnt + 1
                  else cnt )
            in
            Mina_metrics.(
              Cryptography.(
                Counter.inc snark_work_zkapp_base_time_sec
                  (Time.Span.to_sec elapsed) ;
                Counter.inc_one snark_work_zkapp_base_submissions ;
                Counter.inc zkapp_transaction_length
                  (Float.of_int parties_count) ;
                Counter.inc zkapp_proof_updates
                  (Float.of_int proof_parties_count))) ;
            (`Zkapp_command, parties_count, proof_parties_count)
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Signed_command _) ->
            Mina_metrics.(
              Counter.inc Cryptography.snark_work_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Signed_command, 1, 0)
        | Mina_transaction.Transaction.Coinbase _ ->
            Mina_metrics.(
              Counter.inc Cryptography.snark_work_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Coinbase, 1, 0)
        | Mina_transaction.Transaction.Fee_transfer _ ->
            Mina_metrics.(
              Counter.inc Cryptography.snark_work_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Fee_transfer, 1, 0)
      in
      Base_generated
        { transaction_type
        ; elapsed
        ; zkapp_command_count
        ; proof_zkapp_command_count
        }

let emit_proof_metrics (result_with_spec : _ Partitioned_spec.Poly.t) =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match result_with_spec with
  | Partitioned_spec.Poly.Single { job; data; _ } ->
      collect_single ~single_spec:job.spec ~data
  | Partitioned_spec.Poly.Sub_zkapp_command
      { job = { spec = Sub_zkapp_spec.Stable.Latest.Segment { spec; _ }; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      ; _
      } ->
      (* TODO: This should be done once per whole zkapp command
         Mina_metrics.(
           Cryptography.(
             Counter.inc_one snark_work_zkapp_base_submissions ;
      *)
      Perf_histograms.add_span ~name:"snark_worker_subzkapp_time" elapsed ;
      Perf_histograms.add_span
        ~name:"snark_worker_sub_zkapp_command_segment_time" elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc zkapp_transaction_length 1.0 ;
          Counter.inc zkapp_proof_updates
            (match spec with Proved -> 1.0 | _ -> 0.0) ;
          Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed))) ;
      Sub_zkapp_command { kind = `Segment; elapsed }
  | Partitioned_spec.Poly.Sub_zkapp_command
      { job = { spec = Sub_zkapp_spec.Stable.Latest.Merge _; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      ; _
      } ->
      Perf_histograms.add_span ~name:"snark_worker_subzkapp_time" elapsed ;
      Perf_histograms.add_span ~name:"snark_worker_sub_zkapp_command_merge_time"
        elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed))) ;
      Sub_zkapp_command { kind = `Merge; elapsed }
