(** Helper module for setting the execution context logger.

    Useful for very deep call-stack where adding a logger parameter
    to all the functions in the call-chain is too cumbersome. *)

(** [with_logger logger f] runs [f] in a context in which
    a call to [get] will return [logger]. *)
val with_logger : Logger.t option -> (unit -> 'a) -> 'a

(** [get ()] returns the logger bound to the current context (if any),
    or the null logger otherwise. *)
val get : unit -> Logger.t
