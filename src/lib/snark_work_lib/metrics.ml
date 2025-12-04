open Core_kernel

module Transaction_type = struct
  type t = [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
  [@@deriving to_yojson]

  let of_transaction = function
    | Mina_transaction.Transaction.Command
        (Mina_base.User_command.Zkapp_command _) ->
        `Zkapp_command
    | Command (Signed_command _) ->
        `Signed_command
    | Coinbase _ ->
        `Coinbase
    | Fee_transfer _ ->
        `Fee_transfer
end

let emit_single_metrics_impl ~logger
    ~(single_spec : (Transaction_type.t, _) Single_spec.Poly.t) ~elapsed =
  let log_base txn_type =
    [%log info]
      "Base SNARK generated in $elapsed for $transaction_type transaction"
      ~metadata:
        [ ("elapsed", `Float (Time.Span.to_sec elapsed))
        ; ("transaction_type", Transaction_type.to_yojson txn_type)
        ]
  in
  match single_spec with
  | Single_spec.Poly.Merge _ ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      [%log info] "Merge SNARK generated in $elapsed seconds"
        ~metadata:[ ("elapsed", `Float (Time.Span.to_sec elapsed)) ]
  | Transition (_, `Zkapp_command) ->
      Perf_histograms.add_span ~name:"snark_worker_zkapp_transition_time"
        elapsed ;
      Mina_metrics.(
        Cryptography.(Counter.inc_one snark_work_zkapp_base_submissions)) ;
      log_base `Zkapp_command
  | Transition (_, txn_type) ->
      Perf_histograms.add_span ~name:"snark_worker_nonzkapp_transition_time"
        elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc snark_work_nonzkapp_base_time_sec
            (Time.Span.to_sec elapsed) ;
          Counter.inc_one snark_work_nonzkapp_base_submissions)) ;
      log_base txn_type

let emit_single_metrics ~logger ~(single_spec : _ Single_spec.Poly.t) =
  emit_single_metrics_impl ~logger
    ~single_spec:
      (Single_spec.Poly.map ~f_proof:Fn.id
         ~f_witness:(fun { Transaction_witness.transaction = tx; _ } ->
           Transaction_type.of_transaction tx )
         single_spec )

let emit_single_metrics_stable ~logger ~(single_spec : _ Single_spec.Poly.t) =
  emit_single_metrics_impl ~logger
    ~single_spec:
      (Single_spec.Poly.map ~f_proof:Fn.id
         ~f_witness:(fun { Transaction_witness.Stable.Latest.transaction = tx
                         ; _
                         } -> Transaction_type.of_transaction tx )
         single_spec )

let emit_subzkapp_metrics ~logger
    ~(sub_zkapp_spec : Sub_zkapp_spec.Stable.Latest.t) ~elapsed =
  match sub_zkapp_spec with
  | Sub_zkapp_spec.Stable.Latest.Segment { spec; _ } ->
      Perf_histograms.add_span
        ~name:"snark_worker_sub_zkapp_command_segment_time" elapsed ;
      Mina_metrics.(
        Cryptography.(
          Counter.inc_one zkapp_transaction_length ;
          Counter.inc zkapp_proof_updates
            (match spec with Proved -> 1.0 | _ -> 0.0) ;
          Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed))) ;

      [%log info] "Sub-zkApp SNARK generated in $elapsed of type $kind"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("kind", `String "Segment")
          ]
  | Merge _ ->
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
