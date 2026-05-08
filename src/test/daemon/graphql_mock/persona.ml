(** Typed view of the canned persona loaded from [persona.json].

    Keep the record narrow: every field corresponds to something a resolver
    in [mock_resolvers/] reads. When adding a new resolver that needs new
    persona data, extend this record and the JSON together. *)

open Core

(* TODO: ppx_deriving_yojson decoders. Sketch only — the real types here will
   match the GraphQL output shapes more directly so resolvers can return them
   without per-field translation. *)

type daemon =
  { sync_status : string
  ; blockchain_length : int
  ; uptime_secs : int
  ; highest_block_length_received : int
  ; peers : int
  ; block_producer_account : string
  }
[@@deriving yojson]

type account =
  { balance : string
  ; nonce : string
  ; delegate : string
  ; zkapp : Yojson.Safe.t option [@default None]
  }
[@@deriving yojson]

type block =
  { height : int
  ; state_hash : string [@key "stateHash"]
  ; slot : int
  ; creator : string
  ; transactions : string list
  }
[@@deriving yojson]

type mempool_tx =
  { hash : string
  ; kind : string
  ; from_pk : string [@key "from"]
  ; to_pk : string [@key "to"]
  ; amount : string
  ; fee : string
  ; nonce : string
  ; status : string
  }
[@@deriving yojson]

type tx_record =
  { status : string
  ; failure_reason : string option [@key "failureReason"] [@default None]
  ; kind : string option [@default None]
  }
[@@deriving yojson]

type synthetic_hashes =
  { send_payment : string [@key "sendPayment"]
  ; send_delegation : string [@key "sendDelegation"]
  ; send_zkapp_command : string [@key "sendZkappCommand"]
  }
[@@deriving yojson]

type t =
  { daemon : daemon
  ; accounts : (string * account) list
  ; blocks : block list
  ; mempool : mempool_tx list
  ; transactions : (string * tx_record) list
  ; synthetic_tx_hashes : synthetic_hashes [@key "syntheticTxHashes"]
  }
[@@deriving yojson]

(** Load and parse the persona file. Fails loud on any schema mismatch
    so configuration errors surface at startup, not at first request. *)
let load_exn (path : string) : t =
  let json = Yojson.Safe.from_file path in
  match of_yojson json with
  | Ok t ->
      t
  | Error msg ->
      failwithf "graphql_mock: persona %s failed to parse: %s" path msg ()

let find_account (t : t) ~public_key : account option =
  List.Assoc.find t.accounts ~equal:String.equal public_key

let find_tx (t : t) ~hash : tx_record option =
  List.Assoc.find t.transactions ~equal:String.equal hash
