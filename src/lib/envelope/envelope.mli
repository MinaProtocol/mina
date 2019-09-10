open Core

module Sender : sig
  type t = Local | Remote of Unix.Inet_addr.Stable.V1.t
  [@@deriving sexp, eq, yojson]
end

module Incoming : sig
  type 'a t = {data: 'a; sender: Sender.t [@compare.ignore]}
  [@@deriving eq, sexp, yojson, compare]

  val sender : 'a t -> Sender.t

  val data : 'a t -> 'a

  val wrap : data:'a -> sender:Sender.t -> 'a t

  val map : f:('a -> 'b) -> 'a t -> 'b t

  val local : 'a -> 'a t

  val max : f:('a -> 'a -> int) -> 'a t -> 'a t -> 'a t
end
