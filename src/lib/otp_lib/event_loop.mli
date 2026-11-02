(** A loop that handles events one at a time, in the order they are
    submitted. Handling an event never waits: work that does should be
    started by the handler and report back by submitting another event. *)

type 'event t

(** Start a loop that handles each submitted event with [handle]. *)
val create : handle:('event -> unit) -> 'event t

(** Queue [event] to be handled after every event already submitted. *)
val submit : 'event t -> 'event -> unit
