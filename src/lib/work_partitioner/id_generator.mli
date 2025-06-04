type t

val create : logger:Logger.t -> t

val next_id : t -> unit -> int64
