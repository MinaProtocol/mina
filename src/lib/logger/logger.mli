open Core_kernel

[%%versioned:
module Stable : sig
  module V1 : sig
    type t
  end
end]

module Level : sig
  type t =
    | Internal
    | Spam
    | Trace
    | Debug
    | Info
    | Warn
    | Error
    | Faulty_peer
    | Fatal
  [@@deriving
    sexp, equal, compare, yojson, show { with_path = false }, enumerate]

  val of_string : string -> (t, string) result
end

module Time : sig
  include module type of Time

  val to_yojson : t -> Yojson.Safe.t

  val of_yojson : Yojson.Safe.t -> (t, string) Result.t

  val pp : Format.formatter -> t -> unit

  val pretty_to_string : t -> string

  val set_pretty_to_string : (t -> string) -> unit
end

module Source : sig
  type t = { module_ : string [@key "module"]; location : string }
  [@@deriving yojson]

  val create : module_:string -> location:string -> t
end

module Metadata : sig
  [%%versioned:
  module Stable : sig
    module V1 : sig
      type t = Yojson.Safe.t String.Map.t [@@deriving yojson]
    end
  end]
end

(** Used only when dealing with the raw logging function *)
val metadata : t -> Metadata.t

module Message : sig
  type t =
    { timestamp : Time.t
    ; level : Level.t
    ; source : Source.t option
    ; message : string
    ; metadata : Metadata.t
    ; event_id : Structured_log_events.id option
    }
  [@@deriving yojson]
end

(** A Processor is a module which processes structured log
 *  messages into strings. This is used as part of defining
 *  a Consumer. *)
module Processor : sig
  module type S = sig
    type t

    val process : t -> Message.t -> string option
  end

  type t

  val create : (module S with type t = 'processor_data) -> 'processor_data -> t

  val raw : ?log_level:Level.t -> unit -> t

  val raw_structured_log_events : Structured_log_events.Set.t -> t

  val pretty :
    log_level:Level.t -> config:Interpolator_lib.Interpolator.config -> t
end

(** A Transport is a module which represent a destination
 *  for a log strings. This is used as part of defining a
 *  Consumer. *)
module Transport : sig
  module type S = sig
    type t

    val transport : t -> string -> unit
  end

  type t

  val create : (module S with type t = 'transport_data) -> 'transport_data -> t

  (** A transport that calls the given function on each log line *)
  val raw : (string -> unit) -> t

  val stdout : unit -> t
end

(** The Consumer_registry is a global registry where consumers
 *  of the Logger can be registered. Each Consumer consists of
 *  a Processor and a Transport. The processor filters and
 *  serializes structured log messages to strings, and the
 *  transport encapsulates the side effects of the consumer.
 *  Every Consumer is registered under some unique id to
 *  ensure the code does not accidentally attach the same
 *  consumer multiple times. *)
module Consumer_registry : sig
  type id = string

  val register : id:id -> processor:Processor.t -> transport:Transport.t -> unit
end

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
  -> ?event_id:Structured_log_events.id
  -> ('a, unit, string, unit) format4
  -> 'a

val create :
  ?metadata:(string, Yojson.Safe.t) List.Assoc.t -> ?id:string -> unit -> t

val null : unit -> t

val extend : t -> (string, Yojson.Safe.t) List.Assoc.t -> t

val change_id : t -> id:string -> t

val raw : t -> Message.t -> unit

val trace : _ log_function

val internal : _ log_function

val debug : _ log_function

val info : _ log_function

val warn : _ log_function

val error : _ log_function

(** spam is a special log level that omits location information *)
val spam :
     t
  -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
  -> ('a, unit, string, unit) format4
  -> 'a

val faulty_peer : _ log_function [@@deprecated "use Trust_system.record"]

val faulty_peer_without_punishment : _ log_function

val fatal : _ log_function

val append_to_global_metadata : (string * Yojson.Safe.t) list -> unit

module Structured : sig
  (** Logging of structured events. *)

  type log_function =
       t
    -> module_:string
    -> location:string
    -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
    -> Structured_log_events.t
    -> unit

  val trace : log_function

  val debug : log_function

  val info : log_function

  val warn : log_function

  val error : log_function

  val fatal : log_function

  val faulty_peer_without_punishment : log_function

  val best_tip_diff :
       t
    -> ?metadata:(string, Yojson.Safe.t) List.Assoc.t
    -> Structured_log_events.t
    -> unit
end

(** Short alias for Structured. *)
module Str = Structured

module Logger_id : sig
  val mina : Consumer_registry.id

  val best_tip_diff : Consumer_registry.id

  val rejected_blocks : Consumer_registry.id

  val snark_worker : Consumer_registry.id

  val oversized_logs : Consumer_registry.id
end
