(** GraphQL output types parallel to a subset of [Mina_graphql.Types].

    Only the types used by v0.1 resolvers are defined here. When adding a
    new resolver, mirror the shape of the corresponding type in
    [src/lib/graphql/mina_graphql/types.ml] — field names and nullability
    must match, otherwise [mock_schema.json] will diverge from
    [graphql_schema.json] and the drift CI will fail. *)

open Graphql_async
open Schema

(* ---------- Enums ---------- *)

(** Mirrors [Sync_status.t] from the daemon. The string representation
    matches the enum value names in graphql_schema.json. *)
type sync_status =
  | CONNECTING
  | LISTENING
  | OFFLINE
  | BOOTSTRAP
  | SYNCED
  | CATCHUP

let parse_sync_status : string -> sync_status = function
  | "CONNECTING" ->
      CONNECTING
  | "LISTENING" ->
      LISTENING
  | "OFFLINE" ->
      OFFLINE
  | "BOOTSTRAP" ->
      BOOTSTRAP
  | "SYNCED" ->
      SYNCED
  | "CATCHUP" ->
      CATCHUP
  | other ->
      failwith
        ("persona.json: unknown sync status " ^ other
       ^ " (expected one of CONNECTING/LISTENING/OFFLINE/BOOTSTRAP/SYNCED/CATCHUP)"
        )

let sync_status_typ : (Mock_context.t, sync_status option) typ =
  enum "SyncStatus" ~doc:"Sync status of daemon"
    ~values:
      [ enum_value "CONNECTING" ~value:CONNECTING
      ; enum_value "LISTENING" ~value:LISTENING
      ; enum_value "OFFLINE" ~value:OFFLINE
      ; enum_value "BOOTSTRAP" ~value:BOOTSTRAP
      ; enum_value "SYNCED" ~value:SYNCED
      ; enum_value "CATCHUP" ~value:CATCHUP
      ]

(* ---------- DaemonStatus ---------- *)

(* Mirrors a subset of Types.DaemonStatus.t, scoped to scalar/enum fields.
   Object-typed fields (peers, histograms, consensus*, addrs_and_ports,
   metrics, blockProductionKeys, …) remain unimplemented until those
   backing types come online. *)
let daemon_status : (Mock_context.t, Persona.daemon option) typ =
  obj "DaemonStatus" ~fields:(fun _info ->
      [ field "numAccounts" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.num_accounts)
      ; field "blockchainLength" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> Some d.blockchain_length)
      ; field "highestBlockLengthReceived" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.highest_block_length_received )
      ; field "highestUnvalidatedBlockLengthReceived" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.highest_unvalidated_block_length_received )
      ; field "uptimeSecs" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.uptime_secs)
      ; field "ledgerMerkleRoot" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.ledger_merkle_root)
      ; field "stateHash" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.state_hash)
      ; field "chainId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.chain_id)
      ; field "commitId" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.commit_id)
      ; field "confDir" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.conf_dir)
      ; field "userCommandsSent" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.user_commands_sent)
      ; field "snarkWorker" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.snark_worker)
      ; field "snarkWorkFee" ~typ:(non_null int)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.snark_work_fee)
      ; field "syncStatus" ~typ:(non_null sync_status_typ)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            parse_sync_status d.sync_status )
      ; field "coinbaseReceiver" ~typ:string
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.coinbase_receiver)
      ; field "globalSlotSinceGenesisBestTip" ~typ:int
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) ->
            d.global_slot_since_genesis_best_tip )
      ; field "consensusMechanism" ~typ:(non_null string)
          ~args:Arg.[]
          ~resolve:(fun _ (d : Persona.daemon) -> d.consensus_mechanism)
      ] )

(* TODO as resolvers come online:
   - peers / addrs_and_ports / metrics → object types
   - histograms / consensus* → object types
   - account → Account object type (large; nested AnnotatedBalance)
   - send_payment_payload → UserCommand type and sub-types *)
