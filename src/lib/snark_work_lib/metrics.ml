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
      }
  [@@deriving
    register_event
      { msg =
          "Base SNARK generated in $elapsed for $transaction_type transaction"
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
  | Single_spec.Poly.Merge (_, _, _) ->
      Perf_histograms.add_span ~name:"snark_worker_merge_time" elapsed ;
      Mina_metrics.(
        Cryptography.Snark_work_histogram.observe
          Cryptography.snark_work_merge_time_sec (Time.Span.to_sec elapsed)) ;
      Merge_snark_generated { elapsed }
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
      Base_snark_generated { transaction_type; elapsed }

let emit_partitioned_metrics (result_with_spec : _ Partitioned_spec.Poly.t) =
  Mina_metrics.(Counter.inc_one Snark_work.completed_snark_work_received_rpc) ;
  match result_with_spec with
  | Partitioned_spec.Poly.Single { job; data; _ } ->
      emit_single_metrics ~single_spec:job.spec ~data
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
      Sub_zkapp_snark_generated { kind = `Segment; elapsed }
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
      Sub_zkapp_snark_generated { kind = `Merge; elapsed }
