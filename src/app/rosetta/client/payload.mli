(** Decoding of the JSON-valued flags ([--public-key-json],
    [--operations-json], [--signatures-json], ...) into the Rosetta
    models the endpoints expect.

    This is the part of [rosetta-client] that is not command-line
    plumbing: it turns one flag's string into a typed value, or into an
    error that names the flag.  Nothing here prints or exits — the CLI in
    [rosetta_client_cli.ml] decides what to do with a failure.

    Validating here rather than at the server means a malformed payload
    is reported against the flag that carried it, before a request is
    sent. *)

open Core

(** [json ~label s] parses [s] as JSON.  [label] is the flag name, and
    appears in the error. *)
val json : label:string -> string -> Yojson.Safe.t Or_error.t

(** [model ~label of_yojson s] parses [s] as JSON and then decodes it
    through a generated Rosetta model's [of_yojson].  The error
    distinguishes "not JSON at all" from "JSON that does not match the
    schema". *)
val model :
     label:string
  -> (Yojson.Safe.t -> ('a, string) Result.t)
  -> string
  -> 'a Or_error.t

(** [model_opt] is {!model} over an optional flag: [None] in, [None]
    out. *)
val model_opt :
     label:string
  -> (Yojson.Safe.t -> ('a, string) Result.t)
  -> string option
  -> 'a option Or_error.t

(** [json_opt] is {!json} over an optional flag.  Used for the two fields
    the Rosetta schema itself leaves free-form, [metadata] and
    [options], which have no model to decode into. *)
val json_opt : label:string -> string option -> Yojson.Safe.t option Or_error.t
