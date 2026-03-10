open Async
open Mina_base

type t =
  { submitted_at : string
  ; submitter : string
  ; state_hash : State_hash.t
  ; parent : State_hash.t
  ; height : Unsigned.uint32
  ; slot : Mina_numbers.Global_slot_since_genesis.t
  }

let valid_payload_to_yojson (p : t) : Yojson.Safe.t =
  `Assoc
    [ ("submitted_at", `String p.submitted_at)
    ; ("submitter", `String p.submitter)
    ; ("state_hash", State_hash.to_yojson p.state_hash)
    ; ("parent", State_hash.to_yojson p.parent)
    ; ("height", `Int (Unsigned.UInt32.to_int p.height))
    ; ("slot", `Int (Mina_numbers.Global_slot_since_genesis.to_int p.slot))
    ]

let valid_payload_to_cassandra_updates (p : t) =
  [ ("height", Unsigned.UInt32.to_string p.height)
  ; ("slot", Mina_numbers.Global_slot_since_genesis.to_string p.slot)
  ; ("parent", Printf.sprintf "'%s'" @@ State_hash.to_base58_check p.parent)
  ; ( "state_hash"
    , Printf.sprintf "'%s'" @@ State_hash.to_base58_check p.state_hash )
  ; ("raw_block", "NULL")
  ; ("snark_work", "NULL")
  ; ("verified", "true")
  ]

let display valid_payload =
  printf "%s\n" @@ Yojson.Safe.to_string
  @@ valid_payload_to_yojson valid_payload

let display_error e =
  eprintf "%s\n" @@ Yojson.Safe.to_string @@ `Assoc [ ("error", `String e) ]
