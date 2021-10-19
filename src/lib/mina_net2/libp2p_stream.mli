open Async_kernel
open Network_peer

type participant = Us | Them [@@deriving equal]

type t

val id : t -> Libp2p_ipc.stream_id

(** Open a new stream to a remote peer. [release_stream] is called once the stream will no longer be used (for cleaning up any references to stream related data). *)
val open_ :
     logger:Logger.t
  -> helper:Libp2p_helper.t
  -> protocol:string
  -> peer_id:Libp2p_ipc.Builder.PeerId.t
  -> release_stream:(Libp2p_ipc.stream_id -> unit)
  -> t Deferred.Or_error.t

(** Create a new stream type from an existing stream. [release_stream] is called once the stream will no longer be used (for cleaning up any references to stream related data). *)
val create_from_existing :
     logger:Logger.t
  -> helper:Libp2p_helper.t
  -> stream_id:Libp2p_ipc.stream_id
  -> protocol:string
  -> peer:Peer.t
  -> release_stream:(Libp2p_ipc.stream_id -> unit)
  -> t

val protocol : t -> string

val remote_peer : t -> Peer.t

val pipes : t -> string Pipe.Reader.t * string Pipe.Writer.t

val data_received : t -> string -> unit

val reset : helper:Libp2p_helper.t -> t -> unit Deferred.Or_error.t

val stream_closed :
     logger:Logger.t
  -> who_closed:participant
  -> t
  -> [ `Stream_should_be_released of bool ]
