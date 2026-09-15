(** Assembling and logging a PostgreSQL connection URI.

    Kept apart from {!Config} because it is the one place that has to know how
    libpq URIs are shaped: which settings make one up, and where inside one a
    password can hide. *)

open Core

(** The connection URI, from the first of these that is set:
    [--archive-uri], [PG_CONN], or all five of [DB_USERNAME], [PGPASSWORD],
    [DB_HOST], [DB_PORT] and [DB_NAME].

    [flag] is the [--archive-uri] value. [env] reads an environment variable
    and must report an empty variable as unset.

    When the [DB_*] route is taken but incomplete, the error names every
    variable that is unset, not only the first. *)
val resolve :
  flag:string option -> env:(string -> string option) -> Uri.t Or_error.t

(** The URI with every secret replaced, safe to log.

    A libpq URI can carry the password in the userinfo or in a query
    parameter, so both are covered. Anything logging a connection string must
    go through this. *)
val redacted : Uri.t -> string
