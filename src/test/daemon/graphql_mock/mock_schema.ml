(** Composes the mock GraphQL schema.

    Mirrors the shape of [Mina_graphql.schema] — same field names,
    same nullability, parallel resolvers — but reads from the threaded
    [Mock_context.t] (persona) instead of the daemon's runtime.

    See README.md for the rationale on a parallel schema vs. reuse. *)

open Graphql_async
open Schema

(* ---------- Queries ---------- *)

let daemon_status =
  io_field "daemonStatus" ~doc:"Get running daemon status (mock)"
    ~args:[]
    ~typ:(non_null Mock_types.daemon_status)
    ~resolve:(fun { ctx = persona; _ } () ->
      Async.return (Ok persona.Persona.daemon) )

(* TODO: account, bestChain, pooledUserCommands, transactionStatus,
   block, version *)

let queries : Mock_context.t Schema.field list = [ daemon_status ]

(* ---------- Mutations ---------- *)

(* TODO: sendPayment, sendDelegation. v0.1 sketch:
   - parse input shape (same arg types as real schema)
   - light validation (e.g. amount > 0, valid pk shape)
   - return persona.synthetic_tx_hashes.send_payment as the new tx hash
   - do not mutate persona; refresh resets the world *)

let mutations : Mock_context.t Schema.field list = []

(* ---------- Subscriptions ---------- *)

(* v0.1 omits subscriptions. The real daemon exposes newBlock,
   newSyncUpdate, chainReorganization. If the docs playground demos
   any of these, we'll add stubs that emit a single canned event then
   close the stream. *)

let subscriptions : Mock_context.t Schema.subscription_field list = []

(* ---------- Schema ---------- *)

let schema =
  schema queries ~mutations ~subscriptions
