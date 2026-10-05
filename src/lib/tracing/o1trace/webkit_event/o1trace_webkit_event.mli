(** Enable tracing, using the supplied writer.

    Tracing is global, so don't call this more than once in the same process
    and expect multiple trace files!
*)
val start_tracing : Async.Writer.t -> unit

(** Stop tracing and forget about the writer supplied to [start_tracing]. *)
val stop_tracing : unit -> unit
