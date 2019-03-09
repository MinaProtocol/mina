open Core
open Network_peer

module Sender : sig
  module Stable : sig
    module V1 : sig
      type t = Local | Remote of Peer.t [@@deriving sexp, bin_io]
    end
  end

  type t = Local | Remote of Peer.t [@@deriving sexp]
end

module Incoming : sig
  (* TODO: Stable.V1ify *)
  type 'a t = {data: 'a; sender: Sender.Stable.V1.t} [@@deriving sexp, bin_io]

  val sender : 'a t -> Sender.t

  val data : 'a t -> 'a

  val wrap : data:'a -> sender:Sender.t -> 'a t

  val map : f:('a -> 'b) -> 'a t -> 'b t

  val local : 'a -> 'a t
end
