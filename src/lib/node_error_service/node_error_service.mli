type catchup_job_states = Transition_frontier.Full_catchup_tree.job_states =
  { finished : int
  ; failed : int
  ; to_download : int
  ; to_initial_validate : int
  ; wait_for_parent : int
  ; to_verify : int
  ; to_build_breadcrumb : int
  }

val catchup_job_states_to_yojson : catchup_job_states -> Yojson.Safe.t

type node_error_data =
  { version : int
  ; peer_id : string
  ; ip_address : string
  ; public_key : Signature_lib.Public_key.Compressed.t option
  ; git_branch : string
  ; commit_hash : string
  ; chain_id : string
  ; contact_info : string option
  ; hardware_info : string list option
  ; timestamp : string
  ; id : string
  ; error : Yojson.Safe.t
  ; catchup_job_states : catchup_job_states option
  ; sync_status : Sync_status.t
  ; block_height_at_best_tip : int option
  ; max_observed_block_height : int
  ; max_observed_unvalidated_block_height : int
  ; uptime_of_node : string
  }

val node_error_data_to_yojson : node_error_data -> Yojson.Safe.t

val send_node_error_data :
     logger:Logger.t
  -> url:Uri.t
  -> node_error_data
  -> unit Async_kernel__Deferred.t

val send_report :
     logger:Logger.t
  -> node_error_url:string
  -> mina_ref:Mina_lib.t option Core.ref
  -> error:Base.Error.t
  -> contact_info:string option
  -> unit Async.Deferred.t
