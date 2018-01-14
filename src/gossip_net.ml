open Core_kernel
open Async_kernel
open Async_rpc_kernel

module type S =
  functor (Message : sig type t [@@deriving bin_io] end) -> sig
    type t

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; initial_peers     : Peer.t list
        ; target_peer_count : int
        }
    end

    val create
      :  Peer.Event.t Linear_pipe.Reader.t
      -> Params.t
      -> t Deferred.t

    val received : t -> Message.t Linear_pipe.Reader.t

    val broadcast : t -> Message.t Linear_pipe.Writer.t

    val new_peers : t -> Peer.t Linear_pipe.Reader.t

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t list Deferred.t

    val add_handler
      : t
      -> ('q, 'r) Rpc.Rpc.t
      -> ('q -> 'r Or_error.t Deferred.t)
      -> unit

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t
  end

module Make (Message : sig type t [@@deriving bin_io] end) = struct
  type t = Todo

  module Params = struct
    type t =
      { timeout           : Time.Span.t
      ; initial_peers     : Peer.t list
      ; target_peer_count : int
      }
  end

  let create = failwith "TODO"

  let received = failwith "TODO"

  let broadcast = failwith "TODO"

  let new_peers = failwith "TODO"

  let query_random_peers = failwith "TODO"

  let add_handler = failwith "TODO"

  let query_peer = failwith "TODO"
end
