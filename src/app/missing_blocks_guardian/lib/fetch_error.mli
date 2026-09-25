(** Every way reading one block file from a block source can fail.

    The reasons are values rather than strings built where the failure is
    noticed. That keeps two things in one place: the wording an operator
    reads, and {!is_retriable}, which decides whether asking again could
    change the answer. *)

open Core

type t

(** [true] when a second attempt could plausibly succeed: the connection
    failed, the request timed out, or the server answered 5xx. Everything
    else is settled — a 404 or a body that is not JSON returns the same
    answer however often it is asked, and retrying it only delays the real
    message. *)
val is_retriable : t -> bool

(** The operator-facing message. Every case names the location it was
    reading, and an unexpected body is quoted up to a fixed length. *)
val to_error : t -> Error.t

(** {1 Transport failures} *)

val connection_failed : location:string -> exn:Exn.t -> t

val timed_out : location:string -> after:Time_ns.Span.t -> t

(** {1 HTTP status failures}

    [code] is the HTTP status code; the reason phrase is derived from it.
    [body] is the response body, which for an error page is quoted back. *)

val not_found : name:string -> location:string -> t

val redirected : location:string -> code:int -> target:string -> t

val access_refused : location:string -> code:int -> body:string -> t

val server_error : location:string -> code:int -> body:string -> t

val unexpected_status : location:string -> code:int -> body:string -> t

(** {1 Filesystem failures} *)

val file_missing : path:string -> directory:string -> t

val file_unreadable : path:string -> exn:Exn.t -> t

(** {1 Payload failures}

    [where] describes what was read, for example "the response to GET <url>",
    so the message names the source and not only the fault. *)

val empty_body : where:string -> t

val malformed_json : where:string -> reason:string -> body:string -> t
