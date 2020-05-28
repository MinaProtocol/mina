(* structured_events.mli *)

(** extend this type using `deriving register_event`

   a type extension must be a constructor that takes a
    record argument

   each field type in the record must have a type
    that is either an OCaml built-in (like string, int)
    or a type `t` from some module, where the module
    also contains functions {to,from}_yojson

   example extension:

     t += Ctor of {a:int; b:string; c:M.t} [@@deriving register_event]

 *)
type t = ..

(** a value that identifies a `t` constructor *)
type id [@@deriving eq, yojson, sexp]

(** logger, parser for a particular `t` constructor *)
type repr =
  { log: t -> (string * id * (string * Yojson.Safe.json) list) option
  ; parse: id -> (string * Yojson.Safe.json) list -> t option }

(** used by generated code; shouldn't have to call this explicitly *)
val id_of_string : string -> id

(** shouldn't need to call this explicitly; `deriving register_event` should
   call this automatically
*)
val register_constructor : id -> repr -> unit

(** calls logger in some `repr` instance

   returns:
    - log message
    - id
    - field-name,yojson pairs
*)
val log : t -> string * id * (string * Yojson.Safe.json) list

(** calls parser in some `repr` instance
   second argument is field-name,yojson pairs
*)

val parse_exn : id -> (string * Yojson.Safe.json) list -> t
