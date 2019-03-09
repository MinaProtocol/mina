open Core

type t

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
