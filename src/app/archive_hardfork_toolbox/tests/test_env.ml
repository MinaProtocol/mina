(* The PostgreSQL server the tests create their databases on. *)

open Core

let postgres_uri () =
  match Sys.getenv "POSTGRES_URI" with
  | Some uri ->
      uri
  | None ->
      failwith
        "POSTGRES_URI environment variable is not set. Please set it to run \
         the tests."
