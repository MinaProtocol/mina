open Core

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
  | Merge_snark_generated of { time : Time_span_with_json.t }
  [@@deriving register_event { msg = "Merge SNARK generated in $time" }]

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
  | Subzkapp_snark_generated of
      { elapsed : Time_span_with_json.t; kind : [ `Merge | `Segment ] }
  [@@deriving
    register_event
      { msg = "Subzkapp SNARK generated in $elapsed of kind $kind" }]

type Structured_log_events.t +=
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event]

let event_of_snark_work_generated :
    Snark_work_lib.Metrics.snark_work_generated -> Structured_log_events.t =
  function
  | Snark_work_lib.Metrics.Merge_generated time ->
      Merge_snark_generated { time }
  | Snark_work_lib.Metrics.Base_generated
      { transaction_type
      ; elapsed
      ; zkapp_command_count
      ; proof_zkapp_command_count
      } ->
      Base_snark_generated
        { elapsed
        ; transaction_type
        ; zkapp_command_count
        ; proof_zkapp_command_count
        }
  | Snark_work_lib.Metrics.Sub_zkapp_command _ ->
      failwith ""
