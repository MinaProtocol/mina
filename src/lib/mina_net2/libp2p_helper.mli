open Async_kernel

exception Libp2p_helper_died_unexpectedly

type t

val spawn :
     logger:Logger.t
  -> pids:Child_processes.Termination.t
  -> conf_dir:string
  -> handle_push_message:
       (   t
        -> Libp2p_ipc.Reader.DaemonInterface.PushMessage.unnamed_union_t
        -> unit Deferred.t )
  -> t Deferred.Or_error.t

val shutdown : t -> unit Deferred.t

val do_rpc :
     t
  -> ('request, 'response) Libp2p_ipc.Rpcs.rpc
  -> 'request
  -> 'response Deferred.Or_error.t

val send_validation :
     t
  -> validation_id:Libp2p_ipc.validation_id
  -> validation_result:Libp2p_ipc.validation_result
  -> unit
