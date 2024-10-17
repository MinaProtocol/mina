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

module Test_account = struct
  type t =
    { account_name : string
    ; balance : string
    ; timing : Mina_base.Account_timing.t
          [@default Mina_base.Account_timing.Untimed]
    ; permissions : Mina_base.Permissions.t option [@default None]
    ; zkapp : Mina_base.Zkapp_account.t option [@default None]
    }
  [@@deriving yojson]

  let create ~account_name ~balance ?timing ?permissions ?zkapp () =
    { account_name
    ; balance
    ; timing =
        ( match timing with
        | None ->
            Mina_base.Account_timing.Untimed
        | Some timing ->
            timing )
    ; permissions
    ; zkapp
    }
end

module Epoch_data = struct
  module Data = struct
    (* the seed is a field value in Base58Check format *)
    type t = { epoch_ledger : Test_account.t list; epoch_seed : string }
    [@@deriving yojson]
  end

  type t = { staking : Data.t; next : Data.t option } [@@deriving yojson]
end

module Block_producer_node = struct
  type t = { node_name : string; account_name : string } [@@deriving yojson]
end

module Snark_coordinator_node = struct
  type t = { node_name : string; account_name : string; worker_nodes : int }
  [@@deriving yojson]
end

type constants =
  { constraint_constants : Genesis_constants.Constraint_constants.t
  ; genesis_constants : Genesis_constants.t
  ; compile_config : Mina_compile_config.t
  }
[@@deriving to_yojson]

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

type t =
  { requires_graphql : bool
        [@default false]
        (* temporary flag to enable/disable graphql ingress deployments *)
        (* testnet topography *)
  ; genesis_ledger : Test_account.t list
  ; epoch_data : Epoch_data.t option [@default None]
  ; block_producers : Block_producer_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option [@default None]
  ; snark_worker_fee : string [@default "0.025"]
  ; num_archive_nodes : int [@default 0]
  ; log_precomputed_blocks : bool [@default false]
  ; start_filtered_logs : string list
        [@default []]
        (* ; num_plain_nodes : int  *)
        (* blockchain constants *)
  ; proof_config : Runtime_config.Proof_keys.t [@default proof_config_default]
  ; k : int [@default 159]
  ; delta : int [@default 0]
  ; slots_per_epoch : int [@default 3 * 8 * 20]
  ; slots_per_sub_window : int [@default 2]
  ; grace_period_slots : int [@default 140]
  ; txpool_max_size : int [@default 3_000]
  ; slot_tx_end : int option [@default None]
  ; slot_chain_end : int option [@default None]
  ; network_id : string option [@default None]
  ; block_window_duration_ms : int [@default 0]
  ; transaction_capacity_log_2 : int [@default 3]
  }
[@@deriving yojson]

let log_filter_of_event_type ev_existential =
  let open Event_type in
  let (Event_type ev_type) = ev_existential in
  let (module Ty) = event_type_module ev_type in
  match Ty.parse with
  | From_error_log _ ->
      [] (* TODO: Do we need this? *)
  | From_daemon_log (struct_id, _) ->
      [ Structured_log_events.string_of_id struct_id ]
  | From_puppeteer_log _ ->
      []
(* TODO: Do we need this? *)

let default ~(constants : constants) =
  let { constraint_constants; genesis_constants; _ } = constants in
  { requires_graphql =
      true
      (* require_graphql maybe should just be phased out, because it always needs to be enable.  Now with the graphql polling engine, everything will definitely fail if graphql is not enabled.  But even before that, most tests relied on some sort of graphql interaction *)
  ; genesis_ledger = []
  ; epoch_data = None
  ; block_producers = []
  ; snark_coordinator = None
  ; snark_worker_fee = "0.025"
  ; num_archive_nodes = 0
  ; log_precomputed_blocks = false (* ; num_plain_nodes = 0 *)
  ; start_filtered_logs =
      List.bind ~f:log_filter_of_event_type Event_type.all_event_types
  ; proof_config = proof_config_default
  ; k = genesis_constants.protocol.k
  ; slots_per_epoch = genesis_constants.protocol.slots_per_epoch
  ; slots_per_sub_window = genesis_constants.protocol.slots_per_sub_window
  ; grace_period_slots = genesis_constants.protocol.grace_period_slots
  ; delta = genesis_constants.protocol.delta
  ; txpool_max_size = genesis_constants.txpool_max_size
  ; slot_tx_end = None
  ; slot_chain_end = None
  ; network_id = None
  ; block_window_duration_ms = constraint_constants.block_window_duration_ms
  ; transaction_capacity_log_2 = constraint_constants.transaction_capacity_log_2
  }

let transaction_capacity_log_2 (config : t) =
  match config.proof_config.transaction_capacity with
  | None ->
      config.transaction_capacity_log_2
  | Some (Log_2 i) ->
      i
  | Some (Txns_per_second_x10 tps_goal_x10) ->
      let max_coinbases = 2 in
      let block_window_duration_ms =
        Option.value ~default:config.block_window_duration_ms
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
    Option.value ~default:config.block_window_duration_ms
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
