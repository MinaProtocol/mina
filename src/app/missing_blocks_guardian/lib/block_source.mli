(** Where block files are fetched from.

    This module decides {e which} file to ask for and {e how many times};
    {!Http_source} and {!Directory_source} do the asking. *)

open Core
open Async

type t

(** Read the block source setting: an http or https URL, a [file:] URL, or a
    bare filesystem path.

    A bare path is taken exactly as written rather than round-tripped through
    [Uri]: parsing "/data/mina blocks" as a URI and printing it back yields
    "/data/mina%20blocks", so the guardian would look in a directory that
    does not exist and name a path the operator never typed. *)
val create : string -> t Or_error.t

(** Full location of one block file, for logs and error messages. *)
val location : t -> name:string -> string

(** Name of the file holding the block at [height] with [state_hash]. This is
    the layout the archive block buckets use and the one
    [mina-extract-blocks --include-block-height-in-name] writes. *)
val block_file_name :
  network:string -> height:int -> state_hash:string -> string

(** Fetch one block file.

    Only failures that could plausibly succeed on a second attempt are
    retried, up to [retries] further attempts spaced by [retry_delay]; see
    {!Fetch_error.is_retriable}. A 404 or a body that is not JSON fails at
    once, because retrying it only delays the real message. *)
val fetch :
     t
  -> name:string
  -> timeout:Time_ns.Span.t
  -> retries:int
  -> retry_delay:Time_ns.Span.t
  -> logger:Logger.t
  -> Yojson.Safe.t Or_error.t Deferred.t
