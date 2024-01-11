type t

val create : Block_time.Controller.t -> t

(** Schedule [f] to run not before the provided time. If a function is already
scheduled, and the provided time is later than the scheduled time, this function
is ignored. The scheduler always prefers to earliest deadline, and forgets about
all others. *)
val schedule : t -> Block_time.t -> f:(unit -> unit) -> unit