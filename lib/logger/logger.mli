open Core

type t

module Level : sig
  type t =
    | Warn
    | Log
    | Debug
    | Error
  [@@deriving sexp, bin_io]
end

module Attribute : sig
  type t

  val (^=) : string -> Sexp.t -> t
end

module Message : sig
  type t =
    { attributes : Sexp.t String.Map.t
    ; level      : Level.t
    ; pid        : Pid.t
    ; host       : string
    ; time       : Time.t
    ; message    : string
    }
  [@@deriving sexp, bin_io]
end

val create
  : ?level:Level.t
  -> unit
  -> t

val log
  : ?level:Level.t
  -> ?attrs:Attribute.t list
  -> t
  -> ('b, unit, string, unit) format4
  -> 'b

