[%%import "config.mlh"]

[%%import "/src/lib/consensus/mechanism.mlh"]

(* open Core_kernel *)
open Genesis_constants

module Proof_level = struct
  open Proof_level

  [%%inject "compiled", proof_level]

  let compiled = of_string compiled

  let for_unit_tests = Check
end

module Constraint_constants = struct
  open Constraint_constants

  [%%ifdef consensus_mechanism]

  [%%inject "sub_windows_per_window", sub_windows_per_window]

  [%%else]

  (* Invalid value, this should not be used by nonconsensus nodes. *)
  let sub_windows_per_window = -1

  [%%endif]

  [%%inject "ledger_depth", ledger_depth]

  [%%inject "coinbase_amount_string", coinbase]

  [%%inject "account_creation_fee_string", account_creation_fee_int]

  (** All the proofs before the last [work_delay] blocks must be
            completed to add transactions. [work_delay] is the minimum number
            of blocks and will increase if the throughput is less.
            - If [work_delay = 0], all the work that was added to the scan
              state in the previous block is expected to be completed and
              included in the current block if any transactions/coinbase are to
              be included.
            - [work_delay >= 1] means that there's at least two block times for
              completing the proofs.
        *)

  [%%inject "work_delay", scan_state_work_delay]

  [%%inject "block_window_duration_ms", block_window_duration]

  [%%inject "transaction_capacity_log_2", scan_state_transaction_capacity_log_2]

  [%%inject "supercharged_coinbase_factor", supercharged_coinbase_factor]

  let pending_coinbase_depth =
    Core_kernel.Int.ceil_log2
      (((transaction_capacity_log_2 + 1) * (work_delay + 1)) + 1)

  [%%ifndef fork_blockchain_length]

  let fork = None

  [%%else]

  [%%inject "fork_blockchain_length", fork_blockchain_length]

  [%%inject "fork_state_hash", fork_state_hash]

  [%%inject "fork_global_slot_since_genesis", fork_genesis_slot]

  let fork =
    Some
      { Fork_constants.state_hash =
          Data_hash_lib.State_hash.of_base58_check_exn fork_state_hash
      ; blockchain_length = Mina_numbers.Length.of_int fork_blockchain_length
      ; global_slot_since_genesis =
          Mina_numbers.Global_slot_since_genesis.of_int
            fork_global_slot_since_genesis
      }

  [%%endif]

  let compiled =
    { sub_windows_per_window
    ; ledger_depth
    ; work_delay
    ; block_window_duration_ms
    ; transaction_capacity_log_2
    ; pending_coinbase_depth
    ; coinbase_amount =
        Currency.Amount.of_mina_string_exn coinbase_amount_string
    ; supercharged_coinbase_factor
    ; account_creation_fee =
        Currency.Fee.of_mina_string_exn account_creation_fee_string
    ; fork
    }

  let for_unit_tests = compiled
end

[%%inject "genesis_state_timestamp_string", genesis_state_timestamp]

[%%inject "k", k]

[%%inject "slots_per_epoch", slots_per_epoch]

[%%inject "slots_per_sub_window", slots_per_sub_window]

[%%inject "grace_period_slots", grace_period_slots]

[%%inject "delta", delta]

[%%inject "pool_max_size", pool_max_size]

let zkapp_proof_update_cost = 10.26

let zkapp_signed_pair_update_cost = 10.08

let zkapp_signed_single_update_cost = 9.14

let zkapp_transaction_cost_limit = 69.45

let max_event_elements = 100

let max_action_elements = 100

let zkapp_cmd_limit_hardcap = 128

let genesis_time = genesis_time_of_string genesis_state_timestamp_string

let compiled : t =
  { protocol =
      { k
      ; slots_per_epoch
      ; slots_per_sub_window
      ; grace_period_slots
      ; delta
      ; genesis_state_timestamp = genesis_timestamp_of_time genesis_time
      }
  ; txpool_max_size = pool_max_size
  ; num_accounts = None
  ; zkapp_proof_update_cost
  ; zkapp_signed_single_update_cost
  ; zkapp_signed_pair_update_cost
  ; zkapp_transaction_cost_limit
  ; max_event_elements
  ; max_action_elements
  ; zkapp_cmd_limit_hardcap
  }

let for_unit_tests = compiled
