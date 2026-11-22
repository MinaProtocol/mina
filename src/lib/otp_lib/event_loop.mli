(** A loop that handles events one at a time, in the order they are
    submitted. Handling an event never waits: work that does should be
    started by the handler and report back by submitting another event. *)

type 'event t

(** Start a loop that handles each submitted event with [handle], traced as
    the o1trace thread [trace_as_name] if one is given. *)
val create :
  ?trace_as_name:string -> handle:('event -> unit) -> unit -> 'event t

(** Queue [event] to be handled after every event already submitted. *)
val submit : 'event t -> 'event -> unit
