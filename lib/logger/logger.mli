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

  val (:=) : string -> Sexp.t -> t
end

module Message : sig
  type t =
    { attributes : Sexp.t String.Map.t
    ; level      : Level.t
    ; time       : Time.t
    ; pid        : Pid.t
    }
end

val create : unit -> t

val log
  : ?level:Level.t
  -> ?attrs:Attribute.t list
  -> ('b, unit, string, unit) format4
  -> 'b
