open Async
open Core
open Signature_lib

type node_state =
  { peer_id : string
  ; ip_address : string
  ; chain_id : string
  ; public_key : Public_key.Compressed.t option
  ; catchup_job_states : Transition_frontier.Full_catchup_tree.job_states option
  ; block_height_at_best_tip : int option
  ; sync_status : Sync_status.t
  ; hardware_info : string list option
  ; uptime_of_node : string
  }

val set_config :
     get_node_state:(unit -> node_state option Deferred.t)
  -> node_error_url:Uri.t
  -> contact_info:string option
  -> unit

val send_dynamic_report :
  logger:Logger.t -> generate_error:(int -> Yojson.Safe.t) -> unit Deferred.t

val send_report : logger:Logger.t -> error:Error.t -> unit Deferred.t
