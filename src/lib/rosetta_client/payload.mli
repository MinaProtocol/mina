(** Decoding of the JSON-valued CLI flags ([--public-key-json],
    [--operations-json], [--signatures-json], ...) into the Rosetta
    models the endpoints expect.

    This is the input-side twin of {!Data.decode}: that one checks what
    a server sent back, this one checks what a caller is about to send.
    Nothing here prints or exits — the CLI decides what to do with a
    failure.

    Validating here rather than at the server means a malformed payload
    is reported against the flag that carried it, before a request is
    sent. *)

open Core

(** [json_object ~label s] parses [s] as a JSON object.  Used for the two
    fields the Rosetta schema itself leaves free-form, [metadata] and
    [options]: there is no model to decode them into, but the schema
    still types both as objects, so a bare [5] is refused here rather
    than sent. *)
val json_object : label:string -> string -> Yojson.Safe.t Or_error.t

(** [model ~label ~of_yojson ~to_yojson s] parses [s] as JSON and decodes
    it through a generated Rosetta model.  Three failures are
    distinguished: not JSON at all, JSON that the model rejects, and
    JSON the model accepted but did not fully understand — see
    {!unknown_keys}. *)
val model :
     label:string
  -> of_yojson:(Yojson.Safe.t -> ('a, string) Result.t)
  -> to_yojson:('a -> Yojson.Safe.t)
  -> string
  -> 'a Or_error.t

(** [unknown_keys ~path input output] lists the dotted paths of the keys
    in [input] that are missing from [output], where [output] is [input]
    decoded into a model and re-encoded.

    The generated models decode with [strict = false], so a misspelled
    field is dropped in silence; the round trip is what turns that
    silence back into an error.  A key whose value is [null], [[]] or
    [{}] is never reported: those are the values a [\[@default\]]
    swallows on the way out, so their absence says nothing about whether
    the key was understood.  Exposed for testing. *)
val unknown_keys : path:string -> Yojson.Safe.t -> Yojson.Safe.t -> string list
