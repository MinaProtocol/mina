open Core

module type Action_intf = sig
  type t

  val to_trust_increment : t -> float
end

let stub () = failwith "stub"

let insta_ban = 0.

let max_rate _ = 0.

module type S = sig
  type t

  type peer

  type action

  val create : db_dir:string -> t

  val record : t -> peer -> action -> unit

  val lookup : t -> peer -> [`Unbanned of float | `Banned of float * Time.t]

  val close : t -> unit
end

module Make (Peer : sig
  include Hashable.S

  val sexp_of_t : t -> Sexp.t
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
