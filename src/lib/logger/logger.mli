module Stable = Logger__Impl.Stable

type t = Logger__Impl.Stable.V1.t

module Level = Logger__Impl.Level
module Time = Logger__Impl.Time
module Source = Logger__Impl.Source
module Metadata = Logger__Impl.Metadata

val metadata : t -> Logger__Impl.Metadata.t

module Message = Logger__Impl.Message
module Processor = Logger__Impl.Processor
module Transport = Logger__Impl.Transport
module Consumer_registry = Logger__Impl.Consumer_registry

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?tags:Tags.t list
  -> ?metadata:(string, Yojson.Safe.t) Core.List.Assoc.t
  -> ?event_id:Structured_log_events.id
  -> ('a, unit, string, unit) Core.format4
  -> 'a

val create :
  ?metadata:(string, Yojson.Safe.t) Core.List.Assoc.t -> ?id:string -> unit -> t

val null : unit -> t

val extend : t -> (string, Yojson.Safe.t) Core.List.Assoc.t -> t

val change_id : t -> id:string -> t

val raw : t -> Logger__Impl.Message.t -> unit

val trace : 'a log_function

val debug : 'a log_function

val info : 'a log_function

val warn : 'a log_function

val error : 'a log_function

val spam :
     t
  -> ?tags:Tags.t list
  -> ?metadata:(string, Yojson.Safe.t) Core.List.Assoc.t
  -> ('a, unit, string, unit) Core.format4
  -> 'a

(*val faulty_peer : 'a log_function*)

val faulty_peer_without_punishment : 'a log_function

val fatal : 'a log_function

val append_to_global_metadata : (string * Yojson.Safe.t) list -> unit

module Structured = Logger__Impl.Structured
module Str = Structured

module Logger_id : sig
  val mina : Logger__Impl.Consumer_registry.id

  val best_tip_diff : string

  val rejected_blocks : string
end
