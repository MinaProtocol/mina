(** Product: graphql_schema_dump — Dump the Mina GraphQL schema. *)

open Manifest
open Externals

let register () =
  private_executable "graphql_schema_dump" ~path:"src/app/graphql_schema_dump"
    ~deps:
      [ async
      ; async_unix
      ; graphql_async
      ; graphql_parser
      ; yojson
      ; local "genesis_constants"
      ; local "mina_graphql"
      ; local "mina_stdlib"
      ; local "mina_version"
      ]
    ~ppx:Ppx.minimal ;

  ()
