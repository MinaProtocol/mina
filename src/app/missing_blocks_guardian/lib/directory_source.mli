(** Reading one block file from a local directory.

    This is the transport only, the filesystem counterpart of
    {!Http_source}. It knows nothing about archives, gaps or retries. *)

open Core
open Async

(** [read directory ~name] reads [name] from [directory].

    The file is a block only if its contents parse as JSON. A file that is
    not there is reported separately from one that is there and cannot be
    read, because the two call for different fixes. *)
val read :
  string -> name:string -> (Yojson.Safe.t, Fetch_error.t) Result.t Deferred.t
