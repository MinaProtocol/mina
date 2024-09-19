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
  end

  type t = { staking : Data.t; next : Data.t option }
end

module Block_producer_node = struct
  type t = { node_name : string; account_name : string }
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

type t =
  { requires_graphql : bool
        (* temporary flag to enable/disable graphql ingress deployments *)
        (* testnet topography *)
  ; genesis_ledger : Test_account.t list
  ; epoch_data : Epoch_data.t option
  ; block_producers : Block_producer_node.t list
  ; snark_coordinator : Snark_coordinator_node.t option
  ; num_archive_nodes : int
  ; log_precomputed_blocks : bool
  ; start_filtered_logs : string list
  ; genesis_constants : Genesis_constants.t
  ; constraint_constants : Genesis_constants.Constraint_constants.t
  ; proof_level : Genesis_constants.Proof_level.t
  ; compile_config : Mina_compile_config.t
  }

(* TODO: Do we need this? *)

let default ~(constants : constants) =
  { requires_graphql =
      true
      (* require_graphql maybe should just be phased out, because it always needs to be enable.  Now with the graphql polling engine, everything will definitely fail if graphql is not enabled.  But even before that, most tests relied on some sort of graphql interaction *)
  ; genesis_ledger = []
  ; epoch_data = None
  ; block_producers = []
  ; snark_coordinator = None
  ; num_archive_nodes = 0
  ; log_precomputed_blocks = false
  ; start_filtered_logs =
      List.bind ~f:log_filter_of_event_type Event_type.all_event_types
  ; genesis_constants = constants.genesis_constants
  ; constraint_constants =
      { constants.constraint_constants with block_window_duration_ms = 120000 }
  ; proof_level = Full
  ; compile_config =
      { constants.compile_config with
        default_snark_worker_fee = Currency.Fee.of_mina_string_exn "0.025"
      }
  }

let transaction_capacity config =
  let i = config.constraint_constants.transaction_capacity_log_2 in
  Int.pow 2 i

let blocks_for_first_ledger_proof (config : t) =
  let work_delay = config.constraint_constants.work_delay in
  let transaction_capacity_log_2 =
    config.constraint_constants.transaction_capacity_log_2
  in
  ((work_delay + 1) * (transaction_capacity_log_2 + 1)) + 1

let slots_for_blocks blocks =
  (*Given 0.75 slots are filled*)
  Float.round_up (Float.of_int blocks *. 4.0 /. 3.0) |> Float.to_int

let transactions_needed_for_ledger_proofs ?(num_proofs = 1) config =
  let transactions_per_block = transaction_capacity config in
  (blocks_for_first_ledger_proof config * transactions_per_block)
  + (transactions_per_block * (num_proofs - 1))
