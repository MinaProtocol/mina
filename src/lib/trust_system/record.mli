[%%versioned:
module Stable : sig
  module V1 : sig
    type t
  end
end]

module type S = sig
  val init : unit -> t

  val ban : t -> t

  val add_trust : t -> float -> t

  val to_peer_status : t -> Peer_status.t
end

val decay_rate : float

module Make (Now : sig
  val now : unit -> Core.Time.t
end) : S
[@@warning "-67"]
