module Container_images = struct
  type t =
    { mina : string
    ; archive_node : string
    ; user_agent : string
    ; bots : string
    ; points : string
    }
end

module Wallet = struct
  type t = { balance : string; timing : Mina_base.Account_timing.t }
end

type constants =
  { constraints : Genesis_constants.Constraint_constants.t
  ; genesis : Genesis_constants.t
  }
[@@deriving to_yojson]

type t =
  { (* temporary flag to enable/disable graphql ingress deployments *)
    requires_graphql : bool
  ; k : int
  ; delta : int
  ; slots_per_epoch : int
  ; slots_per_sub_window : int
  ; txpool_max_size : int
  ; block_producers : Wallet.t list
  ; extra_genesis_accounts : Wallet.t list
  ; num_snark_workers : int
  ; num_archive_nodes : int
  ; log_precomputed_blocks : bool
  ; snark_worker_fee : string
  ; snark_worker_public_key : string
  ; proof_config : Runtime_config.Proof_keys.t
  }

let proof_config_default : Runtime_config.Proof_keys.t =
  { level = Some Runtime_config.Proof_keys.Level.None
  ; sub_windows_per_window = None
  ; ledger_depth = None
  ; work_delay = None
  ; block_window_duration_ms = Some 30000
  ; transaction_capacity = None
  ; coinbase_amount = None
  ; supercharged_coinbase_factor = None
  ; account_creation_fee = None
  ; fork = None
  }

let default =
  { requires_graphql = false
  ; k = 20
  ; slots_per_epoch = 3 * 8 * 20
  ; slots_per_sub_window = 2
  ; delta = 0
  ; txpool_max_size = 3000
  ; block_producers = []
  ; extra_genesis_accounts = []
  ; num_snark_workers = 0
  ; num_archive_nodes = 0
  ; log_precomputed_blocks = false
  ; snark_worker_fee = "0.025"
  ; snark_worker_public_key =
      (let pk, _ = (Lazy.force Mina_base.Sample_keypairs.keypairs).(0) in
       Signature_lib.Public_key.Compressed.to_string pk)
  ; proof_config = proof_config_default
  }
