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
  | Generating_snark_work_failed of { error : Yojson.Safe.t }
  [@@deriving register_event { msg = "Failed to generate SNARK work: $error" }]
