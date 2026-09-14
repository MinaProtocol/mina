(** What the bytes of a block file must be before they reach the archive.

    Both transports read bytes and neither may assume they hold a block: a
    bucket can answer a request with an XML or HTML error page under any
    status code. This is the single gate they both pass the bytes through. *)

open Core

(** [of_string ~where body] is the decoded block, or the reason [body] is not
    one. [where] describes what was read, for example
    "the response to GET <url>", so the message names the source as well as
    the fault. *)
val of_string :
  where:string -> string -> (Yojson.Safe.t, Fetch_error.t) Result.t
