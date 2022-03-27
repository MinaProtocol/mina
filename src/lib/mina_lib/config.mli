module Snark_worker_config : sig
  type t =
    { initial_snark_worker_key : Signature_lib.Public_key.Compressed.t option
    ; shutdown_on_disconnect : bool
    ; num_threads : int option
    }
end

type t =
  { conf_dir : string
  ; chain_id : string
  ; logger : Logger.t
  ; pids : Child_processes.Termination.t
  ; trust_system : Trust_system.t
  ; monitor : Async_kernel.Monitor.t option
  ; is_seed : bool
  ; disable_node_status : bool
  ; super_catchup : bool
  ; block_production_keypairs : Signature_lib.Keypair.And_compressed_pk.Set.t
  ; coinbase_receiver : Consensus.Coinbase_receiver.t
  ; work_selection_method : (module Work_selector.Selection_method_intf)
  ; snark_worker_config : Snark_worker_config.t
  ; snark_coordinator_key : Signature_lib.Public_key.Compressed.t option
  ; work_reassignment_wait : int
  ; gossip_net_params : Gossip_net.Libp2p.Config.t
  ; net_config : Mina_networking.Config.t
  ; initial_protocol_version : Protocol_version.t
  ; proposed_protocol_version_opt : Protocol_version.t Core_kernel.Option.t
  ; snark_pool_disk_location : string
  ; wallets_disk_location : string
  ; persistent_root_location : string
  ; persistent_frontier_location : string
  ; epoch_ledger_location : string
  ; staged_ledger_transition_backup_capacity : int
  ; time_controller : Block_time.Controller.t
  ; snark_work_fee : Currency.Fee.t
  ; consensus_local_state : Consensus.Data.Local_state.t
  ; is_archive_rocksdb : bool
  ; archive_process_location :
      Core.Host_and_port.t Cli_lib.Flag.Types.with_name option
  ; demo_mode : bool
  ; log_block_creation : bool
  ; precomputed_values : Precomputed_values.t
  ; start_time : Core_kernel.Time.t
  ; precomputed_blocks_path : string option
  ; log_precomputed_blocks : bool
  ; upload_blocks_to_gcloud : bool
  ; block_reward_threshold : Currency.Amount.t option
  ; node_status_url : string option
  ; uptime_url : Uri.t option
  ; uptime_submitter_keypair : Signature_lib.Keypair.t option
  ; stop_time : int
  }

val make :
     conf_dir:string
  -> chain_id:string
  -> logger:Logger.t
  -> pids:Child_processes.Termination.t
  -> trust_system:Trust_system.t
  -> ?monitor:Async_kernel.Monitor.t
  -> is_seed:bool
  -> disable_node_status:bool
  -> super_catchup:bool
  -> block_production_keypairs:Signature_lib.Keypair.And_compressed_pk.Set.t
  -> coinbase_receiver:Consensus.Coinbase_receiver.t
  -> work_selection_method:(module Work_selector.Selection_method_intf)
  -> snark_worker_config:Snark_worker_config.t
  -> ?snark_coordinator_key:Signature_lib.Public_key.Compressed.t option
  -> work_reassignment_wait:int
  -> gossip_net_params:Gossip_net.Libp2p.Config.t
  -> net_config:Mina_networking.Config.t
  -> initial_protocol_version:Protocol_version.t
  -> proposed_protocol_version_opt:Protocol_version.t Core_kernel.Option.t
  -> snark_pool_disk_location:string
  -> wallets_disk_location:string
  -> persistent_root_location:string
  -> persistent_frontier_location:string
  -> epoch_ledger_location:string
  -> ?staged_ledger_transition_backup_capacity:int
  -> time_controller:Block_time.Controller.t
  -> snark_work_fee:Currency.Fee.t
  -> consensus_local_state:Consensus.Data.Local_state.t
  -> ?is_archive_rocksdb:bool
  -> ?archive_process_location:
       Core.Host_and_port.t Cli_lib.Flag.Types.with_name option
  -> ?demo_mode:bool
  -> ?log_block_creation:bool
  -> precomputed_values:Precomputed_values.t
  -> start_time:Core_kernel.Time.t
  -> ?precomputed_blocks_path:string
  -> log_precomputed_blocks:bool
  -> upload_blocks_to_gcloud:bool
  -> ?block_reward_threshold:Currency.Amount.t option
  -> ?node_status_url:string option
  -> ?uptime_url:Uri.t option
  -> ?uptime_submitter_keypair:Signature_lib.Keypair.t option
  -> stop_time:int
  -> unit
  -> t
