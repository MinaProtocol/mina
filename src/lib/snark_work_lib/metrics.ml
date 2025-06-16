open Core_kernel

module Time_span_with_json = struct
  type t = Time.Span.t

  let to_yojson total = `String (Time.Span.to_string_hum total)

  let of_yojson = function
    | `String time ->
        Ok (Time.Span.of_string time)
    | _ ->
        Error "Snark_worker.Functor: Could not parse timespan"
end

(*FIX: register_event fails when adding base types to the constructors*)
module String_with_json = struct
  type t = string

  let to_yojson s = `String s

  let of_yojson = function
    | `String s ->
        Ok s
    | _ ->
        Error "Snark_worker.Functor: Could not parse string"
end

module Int_with_json = struct
  type t = int

  let to_yojson s = `Int s

  let of_yojson = function
    | `Int s ->
        Ok s
    | _ ->
        Error "Snark_worker.Functor: Could not parse int"
end

type Structured_log_events.t +=
  | Merge_snark_generated of { elapsed : Time_span_with_json.t }
  [@@deriving register_event { msg = "Merge SNARK generated in $elapsed" }]

type Structured_log_events.t +=
  | Base_snark_generated of
      { elapsed : Time_span_with_json.t
      ; transaction_type :
          [ `Zkapp_command | `Signed_command | `Coinbase | `Fee_transfer ]
      ; zkapp_command_count : Int_with_json.t
      ; proof_zkapp_command_count : Int_with_json.t
      }
  [@@deriving
    register_event
      { msg =
          "Base SNARK generated in $elapsed for $transaction_type transaction \
           with $zkapp_command_count zkapp_command and \
           $proof_zkapp_command_count proof zkapp_command"
      }]

type Structured_log_events.t +=
  | Sub_zkapp_snark_generated of
      { elapsed : Time_span_with_json.t; kind : [ `Merge | `Segment ] }
  [@@deriving
    register_event
      { msg = "Sub-zkApp SNARK generated in $elapsed of type $kind" }]

let emit_single_metrics ~(single_spec : _ Single_spec.Poly.t)
    ~data:
      ({ data = elapsed; _ } :
        (Core.Time.Stable.Span.V1.t, _) Proof_carrying_data.t ) =
  match single_spec with
  | Merge (_, _, _) ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      Merge_snark_generated { elapsed }
  | Transition (_, ({ transaction; _ } : Transaction_witness.Stable.Latest.t))
    ->
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
              Counter.inc Cryptography.snark_work_non_zkapp_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Signed_command, 1, 0)
        | Mina_transaction.Transaction.Coinbase _ ->
            Mina_metrics.(
              Counter.inc Cryptography.snark_work_non_zkapp_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Coinbase, 1, 0)
        | Mina_transaction.Transaction.Fee_transfer _ ->
            Mina_metrics.(
              Counter.inc Cryptography.snark_work_non_zkapp_base_time_sec
                (Time.Span.to_sec elapsed)) ;
            (`Fee_transfer, 1, 0)
      in
      Base_snark_generated
        { transaction_type
        ; elapsed
        ; zkapp_command_count
        ; proof_zkapp_command_count
        }

let emit_proof_metrics (result_with_spec : _ Partitioned_spec.Poly.t) =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match result_with_spec with
  | Partitioned_spec.Poly.Single { job; data; _ } ->
      emit_single_metrics ~single_spec:job.spec ~data
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
      Sub_zkapp_snark_generated { kind = `Segment; elapsed }
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
      Sub_zkapp_snark_generated { kind = `Merge; elapsed }
