(** Performance log lines, shared by the archive and the diff builder.

    Each line is logged at info level with ["is_perf_metric": true], a
    ["label"] and the elapsed time in milliseconds under ["elapsed"], so they
    can be picked out of the logs. *)

open Core_kernel
open Async

(** Log that [label] took [elapsed]. *)
val report_time :
     logger:Logger.t
  -> label:string
  -> ?extra_metadata:(string * Yojson.Safe.t) list
  -> Time.Span.t
  -> unit

(** Run [f], log how long it took under [label], and return its result. *)
val time :
  label:string -> logger:Logger.t -> (unit -> 'a Deferred.t) -> 'a Deferred.t
