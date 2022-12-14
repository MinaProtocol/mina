[%%import "/src/config.mlh"]

(** This file consists of compile-time constants that are not in
    Genesis_constants.
    This file includes all of the constants defined at compile-time for both
    tests and production.
*)

[%%inject "curve_size", curve_size]

[%%inject "genesis_ledger", genesis_ledger]

[%%inject "default_transaction_fee_string", default_transaction_fee]

[%%inject "default_snark_worker_fee_string", default_snark_worker_fee]

[%%inject "minimum_user_command_fee_string", minimum_user_command_fee]

[%%ifndef compaction_interval]

let compaction_interval_ms = None

[%%else]

[%%inject "compaction_interval", compaction_interval]

let compaction_interval_ms = Some compaction_interval

[%%endif]

let minimum_user_command_fee =
  Currency.Fee.of_mina_string_exn minimum_user_command_fee_string

let default_transaction_fee =
  Currency.Fee.of_mina_string_exn default_transaction_fee_string

let default_snark_worker_fee =
  Currency.Fee.of_mina_string_exn default_snark_worker_fee_string

[%%inject "block_window_duration_ms", block_window_duration]

[%%inject "vrf_poll_interval_ms", vrf_poll_interval]

let rpc_handshake_timeout_sec = 60.0

let rpc_heartbeat_timeout_sec = 60.0

let rpc_heartbeat_send_every_sec = 10.0 (*same as the default*)

[%%inject "generate_genesis_proof", generate_genesis_proof]

(** limits on Zkapp_command.t size
    10.26*np + 10.08*n2 + 9.14*n1 < 69.45
    where np: number of single proof updates
    n2: number of pairs of signed/no-auth update
    n1: number of single signed/no-auth update
    and their coefficients representing the cost
  The formula was generated based on benchmarking data conducted on bare 
  metal i9 processor with room to include lower spec.
  69.45 was the total time for a combination of updates that was considered 
  acceptable.
  The method used to estimate the cost was linear least squares.
*)

let zkapp_proof_update_cost = 10.26

let zkapp_signed_pair_update_cost = 10.08

let zkapp_signed_single_update_cost = 9.14

let zkapp_transaction_cost_limit = 69.45

let max_event_elements = 16

let max_sequence_event_elements = 16
