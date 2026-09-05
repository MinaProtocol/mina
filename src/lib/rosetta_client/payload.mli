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

(** [unknown_keys ~roundtrip json] lists the dotted paths of the keys in
    [json] that the model ignored, where [roundtrip] decodes a document
    through that model and re-encodes it ([None] if it does not decode).

    The generated models decode with [strict = false], so a misspelled
    field is dropped in silence.  A key is called ignored when
    overwriting its value leaves the round trip's output unchanged: a
    key the model reads either shows the new value or rejects it, so
    this separates an unrecognised key from a recognised one that
    happens to hold its [\[@default\]].  Exposed for testing. *)
val unknown_keys :
     roundtrip:(Yojson.Safe.t -> Yojson.Safe.t option)
  -> Yojson.Safe.t
  -> string list
