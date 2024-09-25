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
    ; permissions : Mina_base.Permissions.t option
    ; zkapp : Mina_base.Zkapp_account.t option
    }
  [@@deriving to_yojson]

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
    [@@deriving to_yojson]
  end

  type t = { staking : Data.t; next : Data.t option } [@@deriving to_yojson]
end

module Block_producer_node = struct
  type t = { node_name : string; account_name : string } [@@deriving to_yojson]
end

module Snark_coordinator_node = struct
  type t = { node_name : string; account_name : string; worker_nodes : int }
  [@@deriving to_yojson]
end

type constants =
  { constraint_constants : Genesis_constants.Constraint_constants.t
  ; genesis_constants : Genesis_constants.t
  ; compile_config : Mina_compile_config.t
  ; proof_level : Genesis_constants.Proof_level.t
  }
[@@deriving to_yojson]

type t =
  { requires_graphql : bool
        (* temporary flag to enable/disable graphql ingress deployments *)
        (* testnet topography *)
  ; genesis_ledger : Test_account.t list
  ; epoch_data : Epoch_data.t option
  ; block_producers : Block_producer_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option
  ; snark_worker_fee : string
  ; num_archive_nodes : int
  ; log_precomputed_blocks : bool
  ; start_filtered_logs : string list
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; grace_period_slots : int
  ; txpool_max_size : int
  ; work_delay : int
  ; slot_tx_end : int option
  ; slot_chain_end : int option
  ; network_id : string option
  ; block_window_duration_ms : int
  ; transaction_capacity_log_2 : int
  ; fork : Runtime_config.Fork_config.t option
  }
[@@deriving to_yojson]

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

let default ~constants =
  let { constraint_constants; genesis_constants; compile_config; _ } =
    constants
  in
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
  ; k = genesis_constants.protocol.k
  ; slots_per_epoch = genesis_constants.protocol.slots_per_epoch
  ; slots_per_sub_window = genesis_constants.protocol.slots_per_sub_window
  ; grace_period_slots = genesis_constants.protocol.grace_period_slots
  ; delta = genesis_constants.protocol.delta
  ; txpool_max_size = genesis_constants.txpool_max_size
  ; slot_tx_end = None
  ; slot_chain_end = None
  ; network_id = Some compile_config.network_id
  ; block_window_duration_ms = constraint_constants.block_window_duration_ms
  ; transaction_capacity_log_2 = constraint_constants.transaction_capacity_log_2
  ; work_delay = constraint_constants.work_delay
  ; fork =
      Option.map constraint_constants.fork ~f:(fun fork_constants ->
          { Runtime_config.Fork_config.state_hash =
              Pickles.Backend.Tick.Field.to_string fork_constants.state_hash
          ; blockchain_length =
              Mina_numbers.Length.to_int fork_constants.blockchain_length
          ; global_slot_since_genesis =
              Mina_numbers.Global_slot_since_genesis.to_int
                fork_constants.global_slot_since_genesis
          } )
  }

let apply_runtime_config ~logger runtime_config constants =
  let genesis_constants =
    Or_error.ok_exn
      (Genesis_ledger_helper.make_genesis_constants ~logger
         ~default:constants.genesis_constants runtime_config )
  in
  let constraint_constants =
    Option.value ~default:constants.constraint_constants
      Option.(
        runtime_config.proof
        >>| Genesis_ledger_helper.make_constraint_constants
              ~default:constants.constraint_constants)
  in
  let compile_config =
    Option.value ~default:constants.compile_config
      Option.(
        runtime_config.daemon
        >>| Genesis_ledger_helper.make_compile_config
              ~default:constants.compile_config)
  in
  let proof_level =
    let coerce_proof_level = function
      | Runtime_config.Proof_keys.Level.Full ->
          Genesis_constants.Proof_level.Full
      | Check ->
          Check
      | None ->
          None
    in
    Option.value ~default:constants.proof_level
      Option.(runtime_config.proof >>= fun a -> a.level >>| coerce_proof_level)
  in
  { genesis_constants; constraint_constants; compile_config; proof_level }

let transaction_capacity config = Int.pow 2 config.transaction_capacity_log_2

let blocks_for_first_ledger_proof (config : t) =
  ((config.work_delay + 1) * (config.transaction_capacity_log_2 + 1)) + 1

let slots_for_blocks blocks =
  (*Given 0.75 slots are filled*)
  Float.round_up (Float.of_int blocks *. 4.0 /. 3.0) |> Float.to_int

let transactions_needed_for_ledger_proofs ?(num_proofs = 1) config =
  let transactions_per_block = transaction_capacity config in
  (blocks_for_first_ledger_proof config * transactions_per_block)
  + (transactions_per_block * (num_proofs - 1))
