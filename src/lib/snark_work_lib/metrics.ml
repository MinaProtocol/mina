open Core_kernel

let collect_zkapp_command_metrics cmd =
  let init =
    match
      (Mina_base.Account_update.of_fee_payer
         cmd.Mina_base.Zkapp_command.Poly.fee_payer )
        .authorization
    with
    | Proof _ ->
        (1, 1)
    | _ ->
        (1, 0)
  in
  let parties_count, proof_parties_count =
    Mina_base.Zkapp_command.Call_forest.fold cmd.account_updates ~init
      ~f:(fun (count, proof_updates_count) account_update ->
        ( count + 1
        , if
            Mina_base.Control.(
              Tag.equal Proof
                (tag account_update.Mina_base.Account_update.Poly.authorization))
          then proof_updates_count + 1
          else proof_updates_count ) )
  in
  (`Parties parties_count, `Proof_parties proof_parties_count)

(* TODO: in future refactor, get rid of this witness wrapping with Poly types *)
type any_witness =
  | Stable of Transaction_witness.Stable.Latest.t
  | In_mem of Transaction_witness.t

module Transaction_metrics = struct
  type t =
    | Zkapp_command of { transaction_length : int; proof_updates : int }
    | Signed_command
    | Coinbase
    | Fee_transfer
  [@@deriving to_yojson]

  let of_witness = function
    | Stable w -> (
        match w.transaction with
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Zkapp_command cmd) ->
            let `Parties transaction_length, `Proof_parties proof_updates =
              collect_zkapp_command_metrics cmd
            in
            Zkapp_command { transaction_length; proof_updates }
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Signed_command _) ->
            Signed_command
        | Mina_transaction.Transaction.Fee_transfer _ ->
            Fee_transfer
        | Mina_transaction.Transaction.Coinbase _ ->
            Coinbase )
    | In_mem w -> (
        match w.transaction with
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Zkapp_command cmd) ->
            let `Parties transaction_length, `Proof_parties proof_updates =
              collect_zkapp_command_metrics cmd
            in
            Zkapp_command { transaction_length; proof_updates }
        | Mina_transaction.Transaction.Command
            (Mina_base.User_command.Signed_command _) ->
            Signed_command
        | Mina_transaction.Transaction.Fee_transfer _ ->
            Fee_transfer
        | Mina_transaction.Transaction.Coinbase _ ->
            Coinbase )
end

let emit_single_metrics ~logger
    ~(single_spec : (any_witness, _) Single_spec.Poly.t) ~elapsed =
  match single_spec with
  | Single_spec.Poly.Merge _ ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      [%log info] "Merge SNARK generated in $elapsed seconds"
        ~metadata:[ ("elapsed", `Float (Time.Span.to_sec elapsed)) ]
  | Transition (_, any_witness) ->
      let metrics = Transaction_metrics.of_witness any_witness in
      ( match metrics with
      | Zkapp_command { transaction_length; proof_updates } ->
          Mina_metrics.(
            Cryptography.(
              Counter.inc zkapp_transaction_length
                (Float.of_int transaction_length) ;
              Counter.inc zkapp_proof_updates (Float.of_int proof_updates) ;
              Counter.inc snark_work_zkapp_base_time_sec
                (Time.Span.to_sec elapsed))) ;
          Perf_histograms.add_span ~name:"snark_worker_zkapp_transition_time"
            elapsed ;
          Mina_metrics.(
            Cryptography.(Counter.inc_one snark_work_zkapp_base_submissions))
      | _ ->
          Perf_histograms.add_span ~name:"snark_worker_nonzkapp_transition_time"
            elapsed ;
          Mina_metrics.(
            Cryptography.(
              Counter.inc snark_work_nonzkapp_base_time_sec
                (Time.Span.to_sec elapsed) ;
              Counter.inc_one snark_work_nonzkapp_base_submissions)) ) ;
      [%log info]
        "Base SNARK generated in $elapsed for $transaction_type transaction"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("Transaction_metrics", Transaction_metrics.to_yojson metrics)
          ]

let emit_sub_zkapp_metrics ~logger ~sub_zkapp_spec ~elapsed =
  match sub_zkapp_spec with
  | Sub_zkapp_spec.Segment _ ->
      Perf_histograms.add_span
        ~name:"snark_worker_sub_zkapp_command_segment_time" elapsed ;
      [%log info] "Sub-zkApp SNARK generated in $elapsed of type $kind"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("kind", `String "Segment")
          ]
  | Sub_zkapp_spec.Merge _ ->
      Perf_histograms.add_span ~name:"snark_worker_sub_zkapp_command_merge_time"
        elapsed ;
      [%log info] "Sub-zkApp SNARK generated in $elapsed of type $kind"
        ~metadata:
          [ ("elapsed", `Float (Time.Span.to_sec elapsed))
          ; ("kind", `String "Merge")
          ]
