(** Reading one block file over HTTP.

    This is the transport only: making the request, holding it to a timeout,
    and turning what came back into either a block or a {!Fetch_error.t}. It
    knows nothing about archives, gaps or retries. *)

open Core
open Async

(** [get base ~name ~timeout] fetches [name] from under [base].

    Redirects are not followed. A response is a block only if its body parses
    as JSON, whatever its status code and content type say. *)
val get :
     Uri.t
  -> name:string
  -> timeout:Time_ns.Span.t
  -> (Yojson.Safe.t, Fetch_error.t) Result.t Deferred.t
