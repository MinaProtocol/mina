module Container_images = struct
  type t =
    { mina : string
    ; archive_node : string
    ; user_agent : string
    ; bots : string
    ; points : string
    }
end

(* module Labeled_keypair = Map.Make(String) *)

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

module Snark_worker_node = struct
  type t = { node_name : string; account_name : string; replicas : int }
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
  ; snark_worker : Snark_worker_node.t option
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
  ; snark_worker = None
  ; snark_worker_fee =
      "0.025"
      (* ; snark_worker_public_key =
          (let pk, _ = (Lazy.force Mina_base.Sample_keypairs.keypairs).(0) in
           Signature_lib.Public_key.Compressed.to_string pk ) *)
  ; num_archive_nodes = 0
  ; log_precomputed_blocks = false (* ; num_plain_nodes = 0 *)
  ; proof_config = proof_config_default
  ; k = 20
  ; slots_per_epoch = 3 * 8 * 20
  ; slots_per_sub_window = 2
  ; delta = 0
  ; txpool_max_size = 3000
  }
