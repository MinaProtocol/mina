(* structured_events.mli *)

(** extend this type using `deriving register_event`

   a type extension must be a constructor, either with a
    flat record argument, or no argument

   example extensions:

     t += Ctor1 of {a:int; b:string; c:M.t} [@@deriving register_event]

     t += Ctor2 [@@deriving register_event]

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
val register_constructor : repr -> unit

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
