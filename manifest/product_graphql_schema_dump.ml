(** Product: graphql_schema_dump — Dump the Mina GraphQL schema. *)

open Manifest

let register () =
  private_executable "graphql_schema_dump" ~path:"src/app/graphql_schema_dump"
    ~deps:
      [ opam "async"
      ; opam "async_unix"
      ; opam "graphql-async"
      ; opam "graphql_parser"
      ; opam "yojson"
      ; local "genesis_constants"
      ; local "mina_graphql"
      ; local "mina_stdlib"
      ; local "mina_version"
      ]
    ~ppx:Ppx.minimal ;

  ()
