open Core

type t

module Level : sig
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving bin_io, sexp, compare]
end

module Attribute : sig
  type t = string * string

  val ( ^= ) : string -> string -> t
end

module Message : sig
  type t =
    { attributes: (string * string) list
    ; path: string list
    ; level: Level.t
    ; pid: Pid.t
    ; host: string
    ; timestamp: Time.t
    ; location: string option
    ; message: string }
  [@@deriving bin_io, sexp, yojson]
end

type 'a logger =
     ?loc:string
  -> ?attrs:Attribute.t list
  -> t
  -> ('a, unit, string, unit) format4
  -> 'a

val set_sexp_logging : bool -> unit

val create : unit -> t

val null : unit -> t

val trace : _ logger

val debug : _ logger

val info : _ logger

val warn : _ logger

val error : _ logger

val fatal : _ logger

val faulty_peer : _ logger [@@deprecated "use Trust_system.record"]

val faulty_peer_without_punishment : _ logger

val extend : t -> Attribute.t list -> t

val child : t -> string -> t
