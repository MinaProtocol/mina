(** Product: graphql_schema_dump — Dump the Mina GraphQL schema. *)

open Manifest
open Externals

let () =
  private_executable "graphql_schema_dump" ~path:"src/app/graphql_schema_dump"
    ~deps:
      [ async
      ; async_unix
      ; graphql_async
      ; graphql_parser
      ; yojson
      ; Layer_base.mina_stdlib
      ; Layer_base.mina_version
      ; Layer_domain.genesis_constants
      ; local "mina_graphql"
      ]
    ~ppx:Ppx.minimal
