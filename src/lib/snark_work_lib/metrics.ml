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

(* TODO: remove [emit_zkapp_metrics_legacy] on full delivery
   of new snark coordinator <> worker interaction protocol. *)
let emit_zkapp_metrics_legacy elapsed zkapp_command =
  let init =
    match
      (Mina_base.Account_update.of_fee_payer
         zkapp_command.Mina_base.Zkapp_command.Poly.fee_payer )
        .authorization
    with
    | Proof _ ->
        (1.0, 1.0)
    | _ ->
        (1.0, 0.0)
  in
  let parties_count, proof_parties_count =
    Mina_base.Zkapp_command.Call_forest.fold zkapp_command.account_updates ~init
      ~f:(fun (count, proof_updates_count) account_update ->
        ( count +. 1.0
        , if
            Mina_base.Control.(
              Tag.equal Proof
                (tag account_update.Mina_base.Account_update.Poly.authorization))
          then proof_updates_count +. 1.0
          else proof_updates_count ) )
  in
  Mina_metrics.(
    Cryptography.(
      Counter.inc zkapp_transaction_length parties_count ;
      Counter.inc zkapp_proof_updates proof_parties_count ;
      Counter.inc snark_work_zkapp_base_time_sec (Time.Span.to_sec elapsed)))

(* TODO: remove optional param [on_zkapp_command] on full delivery
   of new snark coordinator <> worker interaction protocol. *)
let emit_single_metrics ~logger ~(single_spec : _ Single_spec.Poly.t)
    ~data:
      ({ data = elapsed; _ } :
        (Core.Time.Stable.Span.V1.t, _) Proof_carrying_data.t )
    ?(on_zkapp_command = fun _ _ -> ()) () =
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
      ( match transaction with
      | Mina_transaction.Transaction.Command
          (Mina_base.User_command.Zkapp_command zkapp_command) ->
          on_zkapp_command elapsed zkapp_command ;
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
          ; ( "transaction_type"
            , Transaction_type.(to_yojson @@ of_transaction transaction) )
          ]

let emit_partitioned_metrics ~logger
    (result_with_spec : _ Partitioned_spec.Poly.t) =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match result_with_spec with
  | Partitioned_spec.Poly.Single { job; data; _ } ->
      emit_single_metrics ~logger ~single_spec:job.spec ~data ()
  | Sub_zkapp_command
      { job = { spec = Sub_zkapp_spec.Stable.Latest.Segment { spec; _ }; _ }
      ; data = Proof_carrying_data.{ data = elapsed; _ }
      ; _
      } ->
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
