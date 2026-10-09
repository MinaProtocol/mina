open Cmdliner

(* Base PostgreSQL server the archive-node tests use. It carries only the
   server location and credentials (no database): each archive node derives its
   own per-test database from it, which the engine creates and drops. Tests
   that run no archive nodes never touch it, so the default is fine for them. *)
let default_postgres_uri = "postgres://postgres:password@127.0.0.1:5432"

type t = { postgres_uri : string }

let postgres_uri_arg =
  let doc =
    "Base PostgreSQL connection URI (server and credentials, no database) used \
     by archive-node tests. The engine creates a per-test database on this \
     server and drops it afterwards. Only relevant for tests that run archive \
     nodes; the default points at a local server."
  in
  let env = Arg.env_var "MINA_TEST_POSTGRES_URI" ~doc in
  Arg.(
    value
    & opt string default_postgres_uri
    & info [ "postgres-uri" ] ~env ~docv:"POSTGRES_URI" ~doc)

let term =
  Term.(const (fun postgres_uri -> { postgres_uri }) $ postgres_uri_arg)
