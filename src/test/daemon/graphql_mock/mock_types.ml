(** GraphQL output types parallel to a subset of [Mina_graphql.Types].

    Only the types used by v0.1 resolvers are defined here. When adding a
    new resolver, mirror the shape of the corresponding type in
    [src/lib/graphql/mina_graphql/types.ml] — field names and nullability
    must match, otherwise [mock_schema.json] will diverge from
    [graphql_schema.json] and the drift CI will fail.

    Scope rule for v0.1: stick to scalar fields (Int, String) on the mock.
    Object-typed fields (peers, histograms, consensusConfiguration), enums
    (syncStatus), and lists of objects/enums require their backing types
    to also be defined here, which we'll add incrementally as resolvers
    need them. *)

open Graphql_async
open Schema

(* DaemonStatus : matches the real Types.DaemonStatus.t structurally for
   the fields we expose. Real has ~30 fields total; v0.1 exposes 4 scalar
   ones the docs use most. *)
let daemon_status : (Mock_context.t, Persona.daemon option) typ =
  obj "DaemonStatus" ~fields:(fun _info ->
      [ field "blockchainLength" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _info (d : Persona.daemon) ->
            Some d.blockchain_length )
      ; field "highestBlockLengthReceived" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _info (d : Persona.daemon) ->
            d.highest_block_length_received )
      ; field "uptimeSecs" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _info (d : Persona.daemon) -> d.uptime_secs)
      ; field "chainId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _info (d : Persona.daemon) -> d.chain_id)
      ] )

(* TODO as resolvers come online:
   - syncStatus → needs SyncStatus enum type definition
   - peers → needs Peer object type
   - account → needs Account object type (large, with nested AnnotatedBalance)
   - send_payment_payload → needs UserCommand type and its sub-types *)
