open Core_kernel

module Transaction_type = struct
  type t = [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
  [@@deriving to_yojson]
end

let emit_single_metrics ~logger ~(single_spec : _ Single_spec.Poly.t)
    ~data:
      ({ data = elapsed; _ } :
        (Core.Time.Stable.Span.V1.t, _) Proof_carrying_data.t ) =
  match single_spec with
  | Single_spec.Poly.Merge (_, _, _) ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      [%log info] "Merge SNARK generated in $elapsed seconds"
        ~metadata:[ ("elapsed", `Float (Time.Span.to_sec elapsed)) ]
  | Transition (_, ({ transaction; _ } : Transaction_witness.Stable.Latest.t))
    ->
      let transaction_type =
        match transaction with
        | Mina_transaction.Transaction.Command (Zkapp_command _) ->
            `Zkapp_command
        | Command (Signed_command _) ->
            `Signed_command
        | Coinbase _ ->
            `Coinbase
        | Fee_transfer _ ->
            `Fee_transfer
      in
      ( match transaction_type with
      | `Zkapp_command ->
          Perf_histograms.add_span ~name:"snark_worker_zkapp_transition_time"
            elapsed ;
          Mina_metrics.(
            Cryptography.(Counter.inc_one snark_work_zkapp_base_submissions))
      | _ ->
          Perf_histograms.add_span ~name:"snark_worker_nonzkapp_transition_time"
            elapsed ;
          Mina_metrics.(
            Counter.inc Cryptography.snark_work_nonzkapp_base_time_sec
              (Time.Span.to_sec elapsed)) ) ;
      [%log info]
        "Base SNARK generated in $elapsed for $transaction_type transaction"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("transaction_type", Transaction_type.to_yojson transaction_type)
          ]

let emit_partitioned_metrics ~logger
    (result_with_spec : _ Partitioned_spec.Poly.t) =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match result_with_spec with
  | Partitioned_spec.Poly.Single { job; data; _ } ->
      emit_single_metrics ~logger ~single_spec:job.spec ~data
  | Sub_zkapp_command
      { job = { spec = Sub_zkapp_spec.Stable.Latest.Segment { spec; _ }; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      ; _
      } ->
      Perf_histograms.add_span
        ~name:"snark_worker_sub_zkapp_command_segment_time" elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc zkapp_transaction_length 1.0 ;
          Counter.inc zkapp_proof_updates
            (match spec with Proved -> 1.0 | _ -> 0.0) ;
          Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed))) ;

      [%log info] "Sub-zkApp SNARK generated in $elapsed of type $kind"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("kind", `String "Segment")
          ]
  | Sub_zkapp_command
      { job = { spec = Sub_zkapp_spec.Stable.Latest.Merge _; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      ; _
      } ->
      Perf_histograms.add_span ~name:"snark_worker_sub_zkapp_command_merge_time"
        elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed))) ;
      [%log info] "Sub-zkApp SNARK generated in $elapsed of type $kind"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("kind", `String "Merge")
          ]
