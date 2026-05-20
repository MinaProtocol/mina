open Core

(* Number of confirmations required for a fork block to be considered final.
   290 is mainnet's consensus constant k (see
   src/lib/node_config/profiled/mainnet.ml): a block is final once k blocks have
   been produced on top of it. Devnet/lightnet use a smaller k, so override with
   --required-confirmations when verifying those networks. *)
let default_required_confirmations = 290

(* Archive schema migration version this toolbox expects. "0.0.5" is the version
   produced by the mesa upgrade (see src/app/archive/upgrade_to_mesa.sql); keep
   it in sync with that file when the schema changes. *)
let default_migration_version = "0.0.5"

(* Hard fork parameters live in a Mina runtime config under proof.fork. We only
   model the proof.fork subtree and ignore every other section (genesis, ledger,
   epoch_data, ...) thanks to [strict = false]. The fork record itself is the
   canonical Runtime_config.Fork_config.t. *)
module Runtime = struct
  module Proof = struct
    type t = { fork : Runtime_config.Fork_config.t }
    [@@deriving yojson { strict = false }]
  end

  type t = { proof : Proof.t } [@@deriving yojson { strict = false }]

  let load path : Runtime_config.Fork_config.t =
    match of_yojson (Yojson.Safe.from_file path) with
    | Ok t ->
        t.proof.fork
    | Error e ->
        failwithf "Failed to parse runtime config %s: %s" path e ()
end

(* Verification parameters that are not part of the runtime config. Every field
   is optional; [pick] resolves CLI overrides and defaults on top of these. *)
module Verify = struct
  type t =
    { latest_state_hash : string option [@default None]
    ; protocol_version : string option [@default None]
    ; required_confirmations : int option [@default None]
    ; migration_version : string option [@default None]
    }
  [@@deriving yojson { strict = false }]

  let empty =
    { latest_state_hash = None
    ; protocol_version = None
    ; required_confirmations = None
    ; migration_version = None
    }

  let load path =
    match of_yojson (Yojson.Safe.from_file path) with
    | Ok t ->
        t
    | Error e ->
        failwithf "Failed to parse verify config %s: %s" path e ()
end

(* Resolve a value in priority order: CLI flag, then config value, then default.
   Raises if none of them provide a value. *)
let pick ~flag ~from_config ~default ~name =
  match List.find_map [ flag; from_config; default ] ~f:Fn.id with
  | Some v ->
      v
  | None ->
      failwithf
        "Missing required parameter %s: provide it as a CLI flag or in the \
         verify config"
        name ()
