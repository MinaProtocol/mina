open Core_kernel

module Container_images = struct
  type t =
    { mina : string
    ; archive_node : string
    ; user_agent : string
    ; bots : string
    ; points : string
    }
end

module Test_Account = struct
  type t =
    { account_name : string
    ; balance : string
    ; timing : Mina_base.Account_timing.t
    }
end

module Block_producer_node = struct
  type t = { node_name : string; account_name : string }
end

module Snark_coordinator_node = struct
  type t = { node_name : string; account_name : string; worker_nodes : int }
  [@@deriving to_yojson]
end

type constants =
  { constraints : Genesis_constants.Constraint_constants.t
  ; genesis : Genesis_constants.t
  }
[@@deriving to_yojson]

type t =
  { requires_graphql : bool
        (* temporary flag to enable/disable graphql ingress deployments *)
        (* testnet topography *)
  ; genesis_ledger : Test_Account.t list
  ; block_producers : Block_producer_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option
  ; snark_worker_fee : string
  ; num_archive_nodes : int
  ; log_precomputed_blocks : bool
        (* ; num_plain_nodes : int  *)
        (* blockchain constants *)
  ; proof_config : Runtime_config.Proof_keys.t
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; txpool_max_size : int
  }

let proof_config_default : Runtime_config.Proof_keys.t =
  { level = Some Full
  ; sub_windows_per_window = None
  ; ledger_depth = None
  ; work_delay = None
  ; block_window_duration_ms = Some 120000
  ; transaction_capacity = None
  ; coinbase_amount = None
  ; supercharged_coinbase_factor = None
  ; account_creation_fee = None
  ; fork = None
  }

let default =
  { requires_graphql = false
  ; genesis_ledger = []
  ; block_producers = []
  ; snark_coordinator = None
  ; snark_worker_fee = "0.025"
  ; num_archive_nodes = 0
  ; log_precomputed_blocks = false (* ; num_plain_nodes = 0 *)
  ; proof_config = proof_config_default
  ; k = 20
  ; slots_per_epoch = 3 * 8 * 20
  ; slots_per_sub_window = 2
  ; delta = 0
  ; txpool_max_size = 3000
  }

let transaction_capacity_log_2 (config : t) =
  match config.proof_config.transaction_capacity with
  | None ->
      Genesis_constants.Constraint_constants.compiled.transaction_capacity_log_2
  | Some (Log_2 i) ->
      i
  | Some (Txns_per_second_x10 tps_goal_x10) ->
      let max_coinbases = 2 in
      let block_window_duration_ms =
        Option.value
          ~default:
            Genesis_constants.Constraint_constants.compiled
              .block_window_duration_ms
          config.proof_config.block_window_duration_ms
      in
      let max_user_commands_per_block =
        (* block_window_duration is in milliseconds, so divide by 1000 divide
           by 10 again because we have tps * 10
        *)
        tps_goal_x10 * block_window_duration_ms / (1000 * 10)
      in
      (* Log of the capacity of transactions per transition.
          - 1 will only work if we don't have prover fees.
          - 2 will work with prover fees, but not if we want a transaction
            included in every block.
          - At least 3 ensures a transaction per block and the staged-ledger
            unit tests pass.
      *)
      1 + Core_kernel.Int.ceil_log2 (max_user_commands_per_block + max_coinbases)

let transaction_capacity config =
  let i = transaction_capacity_log_2 config in
  Int.pow 2 i

let blocks_for_first_ledger_proof (config : t) =
  let work_delay =
    Option.value
      ~default:Genesis_constants.Constraint_constants.compiled.work_delay
      config.proof_config.work_delay
  in
  let transaction_capacity_log_2 = transaction_capacity_log_2 config in
  ((work_delay + 1) * (transaction_capacity_log_2 + 1)) + 1

let slots_for_blocks blocks =
  (*Given 0.75 slots are filled*)
  Float.round_up (Float.of_int blocks *. 4.0 /. 3.0) |> Float.to_int

let transactions_needed_for_ledger_proofs ?(num_proofs = 1) config =
  let transactions_per_block = transaction_capacity config in
  (blocks_for_first_ledger_proof config * transactions_per_block)
  + (transactions_per_block * (num_proofs - 1))
