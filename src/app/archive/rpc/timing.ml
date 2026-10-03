open Core_kernel
open Async

(** [report_time ~label ?extra_metadata elapsed] logs a performance metric with the given [label] and [elapsed] time.
  - [label]: A string describing the metric being reported.
  - [extra_metadata]: An optional list of additional metadata key-value pairs to include in the log (default: []).
  - [elapsed]: The time span to report, as a [Time.Span.t].
  The log entry will include the label, the elapsed time (in human-readable format and milliseconds), and any extra metadata provided.
*)
let report_time ~logger ~label ?(extra_metadata = []) elapsed =
  [%log info] "%s took %s" label
    (Time.Span.to_string_hum elapsed)
    ~metadata:
      ( [ ("is_perf_metric", `Bool true)
        ; ("label", `String label)
        ; ("elapsed", `Float (Time.Span.to_ms elapsed))
        ]
      @ extra_metadata )

(** [time ~label f] measures the execution time of the monadic function [f], reports the elapsed time with the given [label], and returns the result of [f]. 

  @param label A string label used to identify the timing report.
  @param f A function of type unit -> 'a Deferred.t whose execution time will be measured.
  @return The result of [f ()], after reporting the elapsed time.
*)
let time ~label ~logger f =
  let start = Time.now () in
  let%map x = f () in
  let stop = Time.now () in
  let elapsed = Time.diff stop start in
  report_time ~logger ~label elapsed ;
  x
