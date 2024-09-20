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
[@@deriving to_yojson]

(* TODO: Do we need this? *)

let transaction_capacity
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
  let i = constraint_constants.transaction_capacity_log_2 in
  Int.pow 2 i

let blocks_for_first_ledger_proof
    ~(constraint_constants : Genesis_constants.Constraint_constants.t) =
  let work_delay = constraint_constants.work_delay in
  let transaction_capacity_log_2 =
    constraint_constants.transaction_capacity_log_2
  in
  ((work_delay + 1) * (transaction_capacity_log_2 + 1)) + 1

let slots_for_blocks blocks =
  (*Given 0.75 slots are filled*)
  Float.round_up (Float.of_int blocks *. 4.0 /. 3.0) |> Float.to_int

let transactions_needed_for_ledger_proofs ?(num_proofs = 1) constraint_constants
    =
  let transactions_per_block = transaction_capacity ~constraint_constants in
  (blocks_for_first_ledger_proof ~constraint_constants * transactions_per_block)
  + (transactions_per_block * (num_proofs - 1))
