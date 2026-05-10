(** Typed view of the canned persona loaded from [persona.json].

    Strategy: only parse the fields v0.1 resolvers actually consume. Keep
    everything else as raw [Yojson.Safe.t] so the persona file can carry
    forward unparsed sections (accounts, mempool, blocks, etc.) until
    matching resolvers come online. This avoids fighting ppx_deriving_yojson
    over object-keyed JSON shapes that don't map cleanly to OCaml records.

    When adding a resolver that needs a new persona section:
    1. Define a typed record for that section here.
    2. Replace the corresponding [Yojson.Safe.t] field with the typed one.
    3. Update [persona.json] if the JSON shape needs to change. *)

open Core

type daemon =
  { sync_status : string [@key "syncStatus"]
  ; blockchain_length : int [@key "blockchainLength"]
  ; uptime_secs : int [@key "uptimeSecs"]
  ; highest_block_length_received : int [@key "highestBlockLengthReceived"]
  ; peers : int
  ; block_producer_account : string [@key "blockProducerAccount"]
  ; chain_id : string
        [@key "chainId"] [@default "abcd1234efgh5678"]
  }
[@@deriving yojson { strict = false }]

(** Top-level persona. Most fields are raw JSON for now; promote to typed
    records as resolvers come online and need typed access. *)
type t =
  { daemon : daemon
  ; accounts : Yojson.Safe.t [@default `Null]
  ; blocks : Yojson.Safe.t [@default `Null]
  ; mempool : Yojson.Safe.t [@default `Null]
  ; transactions : Yojson.Safe.t [@default `Null]
  ; synthetic_tx_hashes : Yojson.Safe.t
        [@key "syntheticTxHashes"] [@default `Null]
  }
[@@deriving yojson { strict = false }]

(** Load and parse the persona file. Fails loud on any schema mismatch
    so configuration errors surface at startup, not at first request. *)
let load_exn (path : string) : t =
  let json = Yojson.Safe.from_file path in
  match of_yojson json with
  | Ok t ->
      t
  | Error msg ->
      failwithf "graphql_mock: persona %s failed to parse: %s" path msg ()
