open Core

type t

module Level : sig
  type t = Trace | Debug | Info | Warn | Error | Faulty_peer | Fatal
  [@@deriving sexp, compare, yojson]
end

module Time : sig
  include module type of Time

  val to_yojson : t -> Yojson.Safe.json

  val of_yojson : Yojson.Safe.json -> (t, string) Result.t
end

module Source : sig
  type t = {module_: string [@key "module"]; location: string}
  [@@deriving yojson]

  val create : module_:string -> location:string -> t
end

module Metadata : sig
  type t = Yojson.Safe.json String.Map.t [@@deriving yojson]
end

module Message : sig
  type t =
    { timestamp: Time.t
    ; level: Level.t
    ; source: Source.t
    ; message: string
    ; metadata: Metadata.t }
  [@@deriving yojson]
end

type 'a log_function =
     t
  -> module_:string
  -> location:string
  -> ?metadata:(string, Yojson.Safe.json) List.Assoc.t
  -> ('a, unit, string, unit) format4
  -> 'a

val create : ?metadata:(string, Yojson.Safe.json) List.Assoc.t -> unit -> t

val null : unit -> t

val extend : t -> (string, Yojson.Safe.json) List.Assoc.t -> t

val trace : _ log_function

val debug : _ log_function

val info : _ log_function

val warn : _ log_function

val error : _ log_function

val fatal : _ log_function

val faulty_peer : _ log_function
