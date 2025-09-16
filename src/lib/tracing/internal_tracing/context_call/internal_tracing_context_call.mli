(** Helper module for setting the execution context call ID.

    Useful for being able to detect context switches when
    there are concurrent verifier/prover calls. *)

module Call_tag : sig
  type t = string option

  val to_metadata : t -> (string * Yojson.Safe.t) list
end

(** [with_call_id f] runs [f] in a context in which
    an unique identifier and optional [tag] has been associated to the current call. *)
val with_call_id : ?tag:string -> (unit -> 'a) -> 'a

(** [get ()] returns current call ID (and optional tag) bound to the current context (if any),
    or 0 *)
val get : unit -> int * Call_tag.t
