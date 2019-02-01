open Core

module Trust_response = struct
  type t = Insta_ban | Trust_increase of float | Trust_decrease of float
end

module Banned_status = struct
  type t = Unbanned | Banned_until of Time.t
end

module Peer_status = struct
  type t = {trust: float; banned: Banned_status.t}
end

module type Action_intf = sig
  type t

  val to_trust_response : t -> Trust_response.t
end

let stub () = failwith "stub"

let max_rate _ = 0.

module type S = sig
  type t

  type peer

  type action

  val create : db_dir:string -> t

  val record : t -> peer -> action -> unit

  val lookup : t -> peer -> Peer_status.t

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
end) (Now : sig
  val now : unit -> Time.t
end)
(Action : Action_intf)
(Db : Key_value_database.S with type key := Peer.t and type value := Record.t) :
  S with type peer := Peer.t and type action := Action.t = struct
  type t = unit

  let create = stub ()

  let record = stub ()

  let lookup = stub ()

  let close = stub ()
end
