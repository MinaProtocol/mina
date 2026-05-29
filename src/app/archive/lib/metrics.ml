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

let default_missing_blocks_width = 2000

module Q = Archive_health_queries

module Max_block_height = struct
  let update ~logger (module Conn : Mina_caqti.CONNECTION) metric_server =
    time ~label:"max_block_height" ~logger (fun () ->
        let open Deferred.Result.Let_syntax in
        let%map max_height = Q.Max_block_height.run (module Conn) () in
        Mina_metrics.(
          Gauge.set
            (Archive.max_block_height metric_server)
            (Float.of_int max_height)) )
end

module Missing_blocks = struct
  let update ~logger ~missing_blocks_width (module Conn : Mina_caqti.CONNECTION)
      metric_server =
    let open Deferred.Result.Let_syntax in
    time ~label:"missing_blocks" ~logger (fun () ->
        let%map missing_blocks =
          Q.Missing_blocks_count.run (module Conn) ~missing_blocks_width ()
        in
        Mina_metrics.(
          Gauge.set
            (Archive.missing_blocks metric_server)
            (Float.of_int missing_blocks)) )
end

module Unparented_blocks = struct
  let update ~logger (module Conn : Mina_caqti.CONNECTION) metric_server =
    let open Deferred.Result.Let_syntax in
    time ~label:"unparented_blocks" ~logger (fun () ->
        let%map unparented_block_count =
          Q.Unparented_blocks_count.run (module Conn) ()
        in
        Mina_metrics.(
          Gauge.set
            (Archive.unparented_blocks metric_server)
            (Float.of_int unparented_block_count)) )
end

let log_error ~logger pool metric_server
    (f :
         (module Mina_caqti.CONNECTION)
      -> Mina_metrics.Archive.t
      -> (unit, [> Caqti_error.call_or_retrieve ]) Deferred.Result.t ) =
  let open Deferred.Let_syntax in
  match%map
    Mina_caqti.Pool.use
      (fun (module Conn : Mina_caqti.CONNECTION) ->
        f (module Conn) metric_server )
      pool
  with
  | Ok () ->
      ()
  | Error e ->
      [%log warn] "Error updating archive metrics: $error"
        ~metadata:[ ("error", `String (Caqti_error.show e)) ]

let update ~logger ~missing_blocks_width pool metric_server =
  Deferred.all_unit
    (List.map
       ~f:(log_error ~logger pool metric_server)
       [ Max_block_height.update ~logger
       ; Unparented_blocks.update ~logger
       ; Missing_blocks.update ~logger ~missing_blocks_width
       ] )
