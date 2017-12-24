open Core_kernel
open Async_kernel
open Async_rpc_kernel

module type S =
  functor (Message : sig type t [@@deriving bin_io] end) -> sig
    type peer = Host_and_port.t

    type t

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; initial_peers     : peer list
        ; target_peer_count : int
        }
    end

    val create
      :  Peer.Event.t Pipe.Reader.t
      -> Params.t
      -> t Deferred.t

    val received : t -> Message.t Pipe.Reader.t

    val broadcast : t -> Message.t Pipe.Writer.t

    val new_peers : t -> peer Pipe.Reader.t

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
      -> peer
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t
  end

module Make : S
