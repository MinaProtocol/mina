open Core

module Sender : sig
  type t = Local | Remote of (Unix.Inet_addr.Stable.V1.t * Peer.Id.t)
  [@@deriving sexp, eq, yojson, compare]

  val remote_exn : t -> Unix.Inet_addr.Stable.V1.t * Peer.Id.t
end

module Incoming : sig
  type 'a t = {data: 'a; sender: Sender.t}
  [@@deriving eq, sexp, yojson, compare]

  val sender : 'a t -> Sender.t

  val data : 'a t -> 'a

  val wrap : data:'a -> sender:Sender.t -> 'a t

  val wrap_peer : data:'a -> sender:Peer.t -> 'a t

  val map : f:('a -> 'b) -> 'a t -> 'b t

  val local : 'a -> 'a t

  val remote_sender_exn : 'a t -> Unix.Inet_addr.Stable.V1.t * Peer.Id.t

  val gen : 'a Quickcheck.Generator.t -> 'a t Quickcheck.Generator.t
end
