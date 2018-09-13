open Core

type t

module Level : sig
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving sexp, bin_io, compare]
end

module Attribute : sig
  type t = string * Sexp.t

  val ( ^= ) : string -> Sexp.t -> t
end

module Message : sig
  type t =
    { attributes: Sexp.t String.Map.t
    ; path: string list
    ; level: Level.t
    ; pid: Pid.t
    ; host: string
    ; time: Time.t
    ; location: string option
    ; message: string }
  [@@deriving sexp, bin_io]
end

type 'a logger =
     ?loc:string
  -> ?attrs:Attribute.t list
  -> t
  -> ('a, unit, string, unit) format4
  -> 'a

val create : unit -> t

val trace : _ logger

val debug : _ logger

val info : _ logger

val warn : _ logger

val error : _ logger

val fatal : _ logger

val faulty_peer : _ logger

val extend : t -> Attribute.t list -> t

val child : t -> string -> t
