open Core_kernel
module Spec = Work_spec

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

let collect_single ~(single_spec : _ Single_spec.Poly.t)
    ~data:
      ({ data = elapsed; _ } :
        (Core.Time.Stable.Span.V1.t, _) Proof_carrying_data.t ) =
  match single_spec with
  | Single_spec.Poly.Merge (_, _, _) ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;

      (* WARN: This `observe` is just noop, not sure why it's here *)
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      Merge_generated elapsed
  | Single_spec.Poly.Transition
      (_, ({ transaction; _ } : _ Transaction_witness.Poly.t)) ->
      Perf_histograms.add_span ~name:"snark_worker_transition_time" elapsed ;
      let transaction_type, zkapp_command_count, proof_zkapp_command_count =
        match transaction with
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Zkapp_command zkapp_command) ->
            (* WARN: now this is dead code, if we're using new protocol between
               snark coordinator and workers *)
            let init =
              match
                (Mina_base.Account_update.of_fee_payer
                   zkapp_command.Mina_base.Zkapp_command.Poly.fee_payer )
                  .authorization
              with
              | Proof _ ->
                  (1, 1)
              | _ ->
                  (1, 0)
            in
            let parties_count, proof_parties_count =
              Mina_base.Zkapp_command.Call_forest.fold
                zkapp_command.account_updates ~init
                ~f:(fun (count, proof_updates_count) account_update ->
                  ( count + 1
                  , if
                      Mina_base.Control.(
                        Tag.equal Proof
                          (tag
                             account_update
                               .Mina_base.Account_update.Poly.authorization ))
                    then proof_updates_count + 1
                    else proof_updates_count ) )
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

let emit_proof_metrics ~data =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match data with
  | Spec.Poly.Single { single_spec; data; _ } ->
      `One (collect_single ~single_spec ~data)
  | Spec.Poly.Sub_zkapp_command
      { spec = { spec = Zkapp_command_job.Spec.Poly.Segment _; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      } ->
      (* WARN:
         I don't know if this is the desired behavior, we need CI engineers.
         We're likely to adapt the below somehow to here.
         Mina_metrics.(
           Cryptography.(
             Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed) ;
             Counter.inc_one snark_work_zkapp_base_submissions ;
             Counter.inc zkapp_transaction_length (Float.of_int c) ;
             Counter.inc zkapp_proof_updates (Float.of_int p))) ;
      *)
      Perf_histograms.add_span ~name:"snark_worker_subzkapp_time" elapsed ;
      Perf_histograms.add_span
        ~name:"snark_worker_sub_zkapp_command_segment_time" elapsed ;
      `One (Sub_zkapp_command { kind = `Segment; elapsed })
  | Spec.Poly.Sub_zkapp_command
      { spec = { spec = Zkapp_command_job.Spec.Poly.Merge _; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      } ->
      (* WARN:
         I don't know if this is the desired behavior, we need CI engineers.
         We're likely to adapt the below somehow to here.
         Mina_metrics.(
           Cryptography.(
             Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed) ;
             Counter.inc_one snark_work_zkapp_base_submissions ;
             Counter.inc zkapp_transaction_length (Float.of_int c) ;
             Counter.inc zkapp_proof_updates (Float.of_int p))) ;
      *)
      Perf_histograms.add_span ~name:"snark_worker_subzkapp_time" elapsed ;
      Perf_histograms.add_span ~name:"snark_worker_sub_zkapp_command_merge_time"
        elapsed ;
      `One (Sub_zkapp_command { kind = `Merge; elapsed })
