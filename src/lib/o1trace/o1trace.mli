val trace_event : string -> unit

val trace_task : string -> (unit -> 'a) -> 'a

val measure : string -> (unit -> 'a) -> 'a

val start_tracing : Async.Writer.t -> unit
