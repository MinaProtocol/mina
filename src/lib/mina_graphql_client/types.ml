type metrics =
  { block_production_delay : int list
  ; transaction_pool_diff_received : int
  ; transaction_pool_diff_broadcasted : int
  ; transactions_added_to_pool : int
  ; transaction_pool_size : int
  }

type best_chain_block =
  { state_hash : string
  ; command_transaction_count : int
  ; creator_pk : string
  ; height : Mina_numbers.Length.t
  ; global_slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
  ; global_slot_since_hard_fork : Mina_numbers.Global_slot_since_hard_fork.t
  }

type account_data =
  { nonce : Mina_numbers.Account_nonce.t
  ; total_balance : Currency.Balance.t
  ; delegate : Signature_lib.Public_key.Compressed.t option
  ; liquid_balance_opt : Currency.Balance.t option
  ; locked_balance_opt : Currency.Balance.t option
  }

type signed_command_result =
  { id : string
  ; hash : Mina_transaction.Transaction_hash.t
  ; nonce : Mina_numbers.Account_nonce.t
  }

type peer_info = { peer_id : string; host : string; port : int }
[@@deriving yojson]

type daemon_status =
  { sync_status : Sync_status.t
  ; blockchain_length : int option [@yojson.option]
  ; highest_block_length_received : int option [@yojson.option]
  ; uptime_secs : int option [@yojson.option]
  ; state_hash : string option [@yojson.option]
  ; commit_id : string option [@yojson.option]
  ; peer_count : int
  ; peers : peer_info list
  }
[@@deriving yojson]

type readiness =
  { ready : bool
  ; sync_status : Sync_status.t
  ; peer_count : int
  ; blockchain_length : int option [@yojson.option]
  ; highest_block_length_received : int option [@yojson.option]
  }
[@@deriving yojson]

type detailed_chain_block =
  { state_hash : string
  ; command_transaction_count : int
  ; coinbase : Currency.Amount.t
  ; snark_work_count : int
  ; slot : Mina_numbers.Global_slot_since_hard_fork.t
  ; slot_since_genesis : Mina_numbers.Global_slot_since_genesis.t
  }
