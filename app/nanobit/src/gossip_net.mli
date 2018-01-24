open Core
open Async

module type S =
  functor (Message : sig type t [@@deriving bin_io] end) -> sig

    type t =
      { timeout : Time.Span.t
      ; target_peer_count : int
      ; new_peer_reader : Peer.t Linear_pipe.Reader.t
      ; broadcast_writer : Message.t Linear_pipe.Writer.t
      ; received_reader : Message.t Linear_pipe.Reader.t
      ; peers : Peer.Hash_set.t
      }

    module Params : sig
      type t =
        { timeout           : Time.Span.t
        ; target_peer_count : int
        ; address           : Peer.t
        }
    end

    val create
      :  Peer.Event.t Linear_pipe.Reader.t
      -> Params.t
      -> unit Rpc.Implementations.t
      -> t

    val received : t -> Message.t Linear_pipe.Reader.t

    val broadcast : t -> Message.t Linear_pipe.Writer.t

    val broadcast_all : t -> Message.t -> 
      (unit -> bool Deferred.t)

    val query_peer
      : t
      -> Peer.t
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t 

    val query_random_peers
      : t
      -> int
      -> ('q, 'r) Rpc.Rpc.t
      -> 'q
      -> 'r Or_error.t Deferred.t List.t
  end

module Make : S
