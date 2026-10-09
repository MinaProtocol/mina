open Core_kernel
open Async
include Archive_rpc.Timing

let default_missing_blocks_width = 2000

(** [time_ingest metric_server ~source f] runs [f] and records how long it
    took in the [ingest_duration_ms] histogram, under the label [source].

    [f] is the whole RPC handler, so the span measured is the one the sender
    experiences: from the moment the archive accepts the call until the ingest
    loop takes the block off its queue. The loop handles one block at a time,
    so this is the time the block waited behind blocks already being written.
    It does not include the block's own write, which {!time} logs separately.

    [metric_server] is [None] when the archive was started without
    [--metrics-port]. Then nothing is recorded and [f] runs unchanged. *)
let time_ingest metric_server ~source f =
  match metric_server with
  | None ->
      f ()
  | Some metric_server ->
      let start = Time.now () in
      let%map x = f () in
      let elapsed_ms = Time.Span.to_ms (Time.diff (Time.now ()) start) in
      Mina_metrics.(
        Archive.Ingest_duration_histogram.observe
          (Archive.ingest_duration_ms metric_server source)
          elapsed_ms) ;
      x

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
