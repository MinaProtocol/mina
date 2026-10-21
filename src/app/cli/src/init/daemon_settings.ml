open Cli_lib
open Signature_lib
module YJ = Yojson.Safe
module Key = Daemon_file.Key

(** Ports, node-status reporting, snark-work and gossip-logging settings,
    resolved from the flags, the configuration files' [daemon] sections and
    defaults. *)
module Ports_and_work = struct
  type t =
    { libp2p_port : int
    ; rest_server_port : int
    ; limited_graphql_port : int option
    ; client_port : int
    ; snark_work_fee_flag : Currency.Fee.t
    ; node_status_url : string option
    ; work_selection_method : Cli_lib.Arg_type.Work_selection_method.t
    ; work_reassignment_wait : int
    ; log_received_snark_pool_diff : bool
    ; log_transaction_pool_diff : bool
    ; log_block_creation : bool
    ; log_gossip_heard : Mina_networking.Config.log_gossip_heard
    ; run_snark_worker_flag : Public_key.Compressed.t option
    ; run_snark_coordinator_flag : Public_key.Compressed.t option
    ; snark_worker_parallelism_flag : int option
    ; coinbase_receiver_flag : Public_key.Compressed.t option
    }

  let resolve ~logger ~(compile_config : Mina_compile_config.t) daemon_file
      ({ libp2p_port
       ; rest_server_port
       ; limited_graphql_port
       ; client_port
       ; snark_work_fee
       ; node_status_url
       ; work_selection_method_flag
       ; work_reassignment_wait
       ; log_received_snark_pool_diff
       ; log_transaction_pool_diff
       ; log_block_creation
       ; run_snark_worker_flag
       ; run_snark_coordinator_flag
       ; snark_worker_parallelism_flag
       ; coinbase_receiver_flag
       ; _
       } :
        Daemon_flags.t ) =
    let maybe_from_config f keyname actual_value =
      Daemon_file.maybe_from_config ~logger daemon_file f keyname actual_value
    in
    let or_from_config map keyname actual_value ~default =
      Daemon_file.or_from_config ~logger daemon_file map keyname actual_value
        ~default
    in
    let find key actual_value =
      Daemon_file.find ~logger daemon_file key actual_value
    in
    let find_or_default key actual_value ~default =
      Daemon_file.find_or_default ~logger daemon_file key actual_value ~default
    in
    let get_port { Flag.Types.value; default; name } =
      or_from_config YJ.Util.to_int_option name ~default value
    in
    let libp2p_port = get_port libp2p_port in
    let rest_server_port = get_port rest_server_port in
    let limited_graphql_port =
      let ({ value; name } : int option Flag.Types.with_name) =
        limited_graphql_port
      in
      maybe_from_config YJ.Util.to_int_option name value
    in
    let client_port = get_port client_port in
    let snark_work_fee_flag =
      find_or_default Key.snark_worker_fee
        ~default:compile_config.default_snark_worker_fee snark_work_fee
    in
    let node_status_url = find Key.node_status_url node_status_url in
    let work_selection_method =
      find_or_default Key.work_selection
        ~default:Cli_lib.Arg_type.Work_selection_method.Random
        work_selection_method_flag
    in
    let work_reassignment_wait =
      find_or_default Key.work_reassignment_wait
        ~default:Cli_lib.Default.work_reassignment_wait work_reassignment_wait
    in
    let log_received_snark_pool_diff =
      find_or_default Key.log_snark_work_gossip ~default:false
        log_received_snark_pool_diff
    in
    let log_transaction_pool_diff =
      find_or_default Key.log_txn_pool_gossip ~default:false
        log_transaction_pool_diff
    in
    let log_block_creation =
      find_or_default Key.log_block_creation ~default:true log_block_creation
    in
    let log_gossip_heard =
      { Mina_networking.Config.snark_pool_diff = log_received_snark_pool_diff
      ; transaction_pool_diff = log_transaction_pool_diff
      ; new_state = true
      }
    in
    let run_snark_worker_flag =
      find Key.run_snark_worker run_snark_worker_flag
    in
    let run_snark_coordinator_flag =
      find Key.run_snark_coordinator run_snark_coordinator_flag
    in
    let snark_worker_parallelism_flag =
      find Key.snark_worker_parallelism snark_worker_parallelism_flag
    in
    let coinbase_receiver_flag =
      find Key.coinbase_receiver coinbase_receiver_flag
    in
    { libp2p_port
    ; rest_server_port
    ; limited_graphql_port
    ; client_port
    ; snark_work_fee_flag
    ; node_status_url
    ; work_selection_method
    ; work_reassignment_wait
    ; log_received_snark_pool_diff
    ; log_transaction_pool_diff
    ; log_block_creation
    ; log_gossip_heard
    ; run_snark_worker_flag
    ; run_snark_coordinator_flag
    ; snark_worker_parallelism_flag
    ; coinbase_receiver_flag
    }
end

(** The block producer's key file, public key and key-file password, resolved
    from the flags and the configuration files' [daemon] sections. *)
module Block_producer = struct
  type t =
    { block_production_key : string option
    ; block_production_pubkey : Public_key.Compressed.t option
    ; block_production_password : string option
    }

  let resolve ~logger daemon_file
      ({ block_production_key
       ; block_production_pubkey
       ; block_production_password
       ; _
       } :
        Daemon_flags.t ) =
    let find key actual_value =
      Daemon_file.find ~logger daemon_file key actual_value
    in
    let block_production_key =
      find Key.block_producer_key block_production_key
    in
    let block_production_pubkey =
      find Key.block_producer_pubkey block_production_pubkey
    in
    let block_production_password =
      find Key.block_producer_password block_production_password
    in
    { block_production_key; block_production_pubkey; block_production_password }

  (** Where the block producer's keypair comes from. *)
  type keypair_source =
    | No_block_producer
    | Env_private_key of Private_key.t  (** From [MINA_BP_PRIVKEY]. *)
    | Key_file of string
    | Tracked_pubkey of Public_key.Compressed.t
        (** The public key of a keypair in the daemon's wallets. *)

  (** [env_private_key] is the value of [MINA_BP_PRIVKEY]. *)
  let keypair_source ~env_private_key
      { block_production_key; block_production_pubkey; _ } =
    match (block_production_key, block_production_pubkey, env_private_key) with
    | Some _, Some _, _ ->
        Mina_stdlib.Mina_user_error.raise
          "You cannot provide both `block-producer-key` and \
           `block_production_pubkey`"
    | None, Some _, Some _ ->
        Mina_stdlib.Mina_user_error.raise
          "You cannot provide both `MINA_BP_PRIVKEY` and \
           `block_production_pubkey`"
    | None, None, None ->
        No_block_producer
    | None, None, Some base58_privkey -> (
        try Env_private_key (Private_key.of_base58_check_exn base58_privkey)
        with exn ->
          Mina_stdlib.Mina_user_error.raisef
            ~where:"reading the block producer's private key"
            "The environment variable MINA_BP_PRIVKEY is not a valid \
             base58-encoded private key: %s"
            (Core_kernel.Exn.to_string exn) )
    (* CLI argument takes precedence over env variable *)
    | Some sk_file, None, (Some _ | None) ->
        Key_file sk_file
    | None, Some tracked_pubkey, None ->
        Tracked_pubkey tracked_pubkey
end
