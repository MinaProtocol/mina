open Async_kernel

exception Libp2p_helper_died_unexpectedly

type t

(** [allow_multiple_instances] defaults to `false`; set it
    to `true` for tests that require multiple libp2p helpers
*)
val spawn :
     ?allow_multiple_instances:bool
  -> logger:Logger.t
  -> pids:Child_processes.Termination.t
  -> conf_dir:string
  -> handle_push_message:
       (   t
        -> Libp2p_ipc.Reader.DaemonInterface.PushMessage.unnamed_union_t
        -> unit Deferred.t )
  -> unit
  -> t Deferred.Or_error.t

val shutdown : t -> unit Deferred.t

val do_rpc :
     t
  -> ('request, 'response) Libp2p_ipc.Rpcs.rpc
  -> 'request
  -> 'response Deferred.Or_error.t

val send_validation :
     validation_id:Libp2p_ipc.validation_id
  -> validation_result:Libp2p_ipc.validation_result
  -> t
  -> unit

val send_add_resource :
     tag:Staged_ledger_diff.Body.Tag.t
  -> body:Staged_ledger_diff.Body.t
  -> t
  -> unit

val send_heartbeat : peer_id:Network_peer.Peer.Id.t -> t -> unit

val test_with_libp2p_helper :
     ?logger:Logger.t
  -> ?handle_push_message:
       (   t
        -> Libp2p_ipc.Reader.DaemonInterface.PushMessage.unnamed_union_t
        -> unit Deferred.t )
  -> (string -> t -> 'a Deferred.t)
  -> 'a
