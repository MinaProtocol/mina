(** GraphQL output types parallel to a subset of [Mina_graphql.Types].

    Only the types used by v0.1 resolvers are defined here. When adding a
    new resolver, mirror the shape of the corresponding type in
    [src/lib/graphql/mina_graphql/types.ml] — field names and nullability
    must match, otherwise [mock_schema.json] will diverge from
    [graphql_schema.json] and the drift CI will fail.

    Convention: every [t] here is a [(Mock_context.t, _) Graphql_async.Schema.typ]. *)

open Graphql_async
open Schema

(* TODO: actual types. Sketches below show the intended shape; resolvers in
   mock_resolvers/ will populate fields by reading from the threaded persona
   in [Mock_context.t]. *)

(* daemon_status : matches mina_graphql/types.ml DaemonStatus.t *)
let daemon_status : (Mock_context.t, Persona.daemon option) typ =
  obj "DaemonStatus" ~fields:(fun _info ->
      [ field "syncStatus" ~typ:(non_null string) ~args:[]
          ~resolve:(fun _info (d : Persona.daemon) -> d.sync_status)
      ; field "blockchainLength" ~typ:int ~args:[]
          ~resolve:(fun _info (d : Persona.daemon) -> Some d.blockchain_length)
      ; field "uptimeSecs" ~typ:(non_null int) ~args:[]
          ~resolve:(fun _info (d : Persona.daemon) -> d.uptime_secs)
      ; field "peers" ~typ:(non_null int) ~args:[]
          ~resolve:(fun _info (d : Persona.daemon) -> d.peers)
      ; field "blockProducer" ~typ:string ~args:[]
          ~resolve:(fun _info (d : Persona.daemon) ->
            Some d.block_producer_account )
      ] )

(* account, send_payment_payload, mempool_user_command, …
   to be added incrementally as resolvers come online. *)
